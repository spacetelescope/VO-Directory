using System;
using System.Data.SqlClient;
using System.Data;
using System.Text;
using log4net;

using registry;

namespace Replicate
{
    public enum HarvestStatus
    {
        Success, //0
        Failure,
        PartialFailure,
        NoRecords,
        Unknown
    };

    class Replicate
	{
		const int MAX_LEN_LOG = 4000;
        private static DateTime harvestingEpoch = DateTime.Parse("2000-JAN-01");

        //because we need to write to the log table, this is an admin connection
        private static string connStr = Properties.Settings.Default.SqlAdminConnection;
        private static string dbAdmin = Properties.Settings.Default.dbAdmin;
		private static readonly ILog log = LogManager.GetLogger (typeof(Replicate));

		public static DateTime lookupLastRep(string fromReg, out bool everHarvested)
		{
			SqlConnection conn = null;
            DateTime ret = harvestingEpoch;
            everHarvested = false;

			try 
			{
				conn = new SqlConnection(connStr);
				conn.Open();

				string s = " select top 1 date from HarvesterLog where ServiceURL ='";
				s += fromReg+"' and status = 0 order by date desc";
				SqlCommand cmd =conn.CreateCommand();
				cmd.CommandText=s;
				try 
				{
					ret = (DateTime)cmd.ExecuteScalar();
                    everHarvested = true;
				} 
				catch (Exception) 
				{
                    // there is no prior successful log entry
                    ret = harvestingEpoch;
				}
			}
			finally
			{
				conn.Close();
			}

			return ret;
		}
		
		public static bool writeStartLog(string from, DateTime start, string type )
		{
			SqlConnection conn = null;

            try
            {
                conn = new SqlConnection(connStr);
                conn.Open();

                string s = " insert into HarvesterLog (date, type, ServiceURL) values ('";
                s += start.ToString() + "',";
                s += "'" + type + "',";
                s += "'" + from + "') ";
                SqlCommand cmd = conn.CreateCommand();
                cmd.CommandText = s;
                cmd.ExecuteNonQuery();
            }
            catch
            {
                return false;
            }
			finally
			{
				conn.Close();
			}

            return true;
		}

		public static bool writeEndLog(DateTime date,  string message, HarvestStatus status, string url )
		{

			SqlConnection conn = null;
            try
            {
                conn = new SqlConnection(connStr);
                conn.Open();
                if (message.Length > MAX_LEN_LOG)
                {
                    message = message.Substring(0, MAX_LEN_LOG);
                }
                message = message.Replace('\'', ' ');
                message = message.Replace('<', '(').Replace('>', ')'); //raw record creating html in reporting errors: we don't really need it anyway.

                string s = " update HarvesterLog set message=";
                s += "'" + message + "',";
                s += "status=" + (int)status;
                s += " where [date]='" + date.ToString() + "' and ServiceURL = '" + url + "' ";
                SqlCommand cmd = conn.CreateCommand();
                cmd.CommandText = s;
                //				Console.Out.Write(s);
                cmd.ExecuteNonQuery();
            }
            catch (Exception)
            {
                return false;
            }
			finally
			{
				conn.Close();
			}
            return true;
		}

        public static void harvestDatabaseRegistryList()
        {
            RegistryDBQuery reg = new RegistryDBQuery();
            HarvestAdmin harvest = new HarvestAdmin();

            // This is using the dll directly, picks up connection string from
            // the replicate.exe.config
            string rq = "select distinct ServiceUrl, RegistryID from Harvester where (DoHarvest = 1)";
            DataSet ds = reg.DSQuery(rq, dbAdmin);
            StringBuilder sb = new StringBuilder();
            Console.Out.WriteLine("Harvesting ....\n");

            foreach (DataRow dr in ds.Tables[0].Rows)
            {
                HarvestStatus stat = HarvestStatus.Success;
                sb.Remove(0, sb.Length);
                string url = (string)dr["ServiceUrl"];
                string regid = (string)dr["RegistryID"];
                bool everHarvested = false;
                DateTime last = Replicate.lookupLastRep(url, out everHarvested);

                //Add a days' worth of leeway if not harvesting since the start of harvesting epoch.
                //Ticks finagling is for UTC.
                if( everHarvested )
                    last = new DateTime(last.Ticks - (last.Ticks % TimeSpan.TicksPerSecond), last.Kind).AddDays(-1);

                DateTime startTime = DateTime.Now.ToUniversalTime();
                startTime = new DateTime(startTime.Ticks - (startTime.Ticks % TimeSpan.TicksPerSecond), startTime.Kind);

                bool wroteStartLog = Replicate.writeStartLog(url, startTime, "harvest");
                if (wroteStartLog)
                {
                    sb.Append(last);
                    sb.Append(" ");
                    try
                    {
                        Console.Out.WriteLine("trying :" + url + " since (last success minus 1 day) " + last);
                        string res = harvest.HarvestOAI(url, regid, last, true, dbAdmin);
                        sb.Append(res);
                    }
                    catch (Exception e)
                    {
						log.Error ("Error harvesting from url " + url, e);
                        sb.Append(e);
                        stat = HarvestStatus.Failure;
                    }

                    // Ugly list of cases from experience that might have been an error:
                    string mes = sb.ToString();
                    if (mes.Contains("Error harvesting from url"))
                    {
                        if (mes.Contains("No Records to Harvest")) //test: in case of hidden timeout errors.
                            stat = HarvestStatus.NoRecords;
                        else if (mes.Contains("Loaded 0 RESOURCES"))
                            stat = HarvestStatus.PartialFailure;
                    }
                    else if (mes.Contains("Harvester Error"))
                    {
                        stat = HarvestStatus.Failure;
                    }
                    else if (mes.Contains("Loaded") && mes.Contains("Got"))
                    {
                        string loaded = mes.Substring(mes.IndexOf("Loaded") + 7, mes.IndexOf("RESOURCES", mes.IndexOf("Loaded")) - (mes.IndexOf("Loaded") + 7)).Trim();
                        string got = mes.Substring(mes.IndexOf("Got") + 4, mes.IndexOf("recs") - (mes.IndexOf("Got") + 4)).Trim();

                        string skipped = "0";
                        if (mes.Contains("Skipped"))
                        {
                            int skip = mes.IndexOf("Skipped");
                            skipped = mes.Substring(skip + 8, mes.IndexOf("RESOURCES", skip) - (skip + 8)).Trim();
                        }
                        if ((Convert.ToInt32(skipped) + Convert.ToInt32(loaded)) != Convert.ToInt32(got))
                            stat = HarvestStatus.PartialFailure;
                    }
                    if (sb.Length > 1000)
                    {
                        mes = mes.Substring(mes.Length - 1000, 999);
                    }
                    else
                    {
                        Console.Out.WriteLine(sb.ToString() + "\n");
                    }
                    bool wroteEnd = Replicate.writeEndLog(startTime, sb.ToString(), stat, url);
                    if (wroteEnd == false)
                    {
                        logfile errlog = new logfile(Harvester.logFileName);
                        if (errlog.Log("Failed to write end log DB entry for " + url) == false)
                            Console.Out.WriteLine("Failed to log DB write error for " + url);
                    }
                }
                else
                {
                    logfile errlog = new logfile(Harvester.logFileName);
                    if (errlog.Log("Failed to write start log DB entry for " + url) == false)
                        Console.Out.WriteLine("Failed to log DB write error for " + url);
                }
            }
            Console.Out.WriteLine("Finished Harvest.\n");
        }

	}
}
