using System;
using System.Collections;
using System.ComponentModel;
using System.Data;
using System.Diagnostics;
using System.Web;
using System.Web.Services;
using System.Data.SqlClient;
using System.Text;
using System.Configuration;
using registry;
using ivoa.net.vr1_0;
using ivoa.net.ri1_0.server;
using log4net;

using ivoa.altVOTable;

namespace registry
{
	/// <summary>
	/// Summary description for Registry.
	///Current version
	///ID:		$Id: Registry.asmx.cs,v 1.3 2006/02/28 17:09:49 grgreene Exp $
	///Revision:	$Revision: 1.3 $
	///Date:	$Date: 2006/02/28 17:09:49 $
	/// </summary>
	[System.Web.Services.WebService(Namespace="http://www.us-vo.org")]//
	public class Registry : System.Web.Services.WebService
	{
		public static string sConnect;
        private static logfile errLog;
		private static readonly ILog log = LogManager.GetLogger (typeof(Registry));

        //private static logfile genericLog;

		
		public Registry()
		{
			//CODEGEN: This call is required by the ASP.NET Web Services Designer
			InitializeComponent();
            try
            {
                sConnect = (string)System.Configuration.ConfigurationManager.AppSettings["SqlConnection"];
            }
            catch (Exception) { }

			if (sConnect == null)
				throw new Exception ("Registry: SqlConnection.String not found in configuration settings");

            StartLogFiles();
		}

		public Registry(string connectionString)
		{
			//CODEGEN: This call is required by the ASP.NET Web Services Designer
			InitializeComponent();
            try
            {
                sConnect = (string)System.Configuration.ConfigurationManager.AppSettings["SqlConnection"];
            }
            catch (Exception) { }

			if (sConnect == null)
				sConnect = connectionString;

            StartLogFiles();
		}

        private static void StartLogFiles()
        {
            errLog = new logfile("err_RegistryService.log");
            /*genericLog = new logfile("RegistryService.log");

            if( genericLog != null )
                genericLog.Log(DateTime.Now.ToShortDateString() + " -- Registry page loaded");*/
        }

		#region Component Designer generated code
		
		//Required by the Web Services Designer 
		private IContainer components = null;
				
		/// <summary>
		/// Required method for Designer support - do not modify
		/// the contents of this method with the code editor.
		/// </summary>
		private void InitializeComponent()
		{
		}

		/// <summary>
		/// Clean up any resources being used.
		/// </summary>
		protected override void Dispose( bool disposing )
		{
			if(disposing && components != null)
			{
				components.Dispose();
			}
			base.Dispose(disposing);		
		}
		
		#endregion

        [WebMethod(Description = "Returns VOResources with status=1: Input WHERE predicate for SQL Query")]
        public ivoa.net.ri1_0.server.Resource[] QueryXMLRIResource(string predicate)
        {
            string cmd = SQLHelper.createXMLResourceSelect(predicate);
            return SQLQueryRI10Resource(cmd);
        }

        [WebMethod(Description = "Returns VOResources with status=1: Input WHERE predicate for SQL Query")]
        public System.Xml.XmlDocument[] QueryRIResourceXMLDoc(string predicate)
        {
            string cmd = SQLHelper.createXMLResourceSelect(predicate);
            return SQLQueryRI10ResourceXMLDoc(cmd);
        }

        [WebMethod(Description = "Returns VOResources with status=1: Input WHERE predicate for SQL Query, bool include deleted, bool include inactive")]
        public System.Xml.XmlDocument[] QueryRIResourceXMLDocAllResources(string predicate, bool withDeleted, bool withInactive, ArrayList queryParams = null)
        {
            string cmd = SQLHelper.createXMLResourceSelect(predicate, withDeleted, withInactive);
            return SQLQueryRI10ResourceXMLDoc(cmd, queryParams);
        }

        [WebMethod(Description = "Returns VOResources with status=1 and 3: Input WHERE predicate for SQL Query")]
        public System.Xml.XmlDocument[] QueryRIResourceRankedXMLDoc(string keywords, bool andKeys)
        {
            string cmd = SQLHelper.createXMLRankedResourceSelect(keywords, andKeys);
            return SQLQueryRI10ResourceXMLDoc(cmd);
        }


        [WebMethod(Description = "Returns VOResources with status=1, filtered by capability Input capability substring, WHERE predicate for SQL Query")]
        public System.Xml.XmlDocument[] QueryCapabilityResourceXMLDoc(string predicate, string capability)
        {
            if (predicate.Length == 0 && capability.Length == 0)
                return new System.Xml.XmlDocument[0];

            string cmd = SQLHelper.TranslateOldSchemaQuery(SQLHelper.createXMLCapabilityResourceSelect(predicate, capability));
            return SQLQueryRI10ResourceXMLDoc(cmd);
        }

        [WebMethod(Description = "Returns VOResources with status=1, filtered by capability Input capability substring, WHERE predicate for SQL Query")]
        public System.Xml.XmlDocument[] QueryCapBandResourceXMLDoc(string predicate, string capability, string band)
        {
            string cmd = SQLHelper.TranslateOldSchemaQuery( SQLHelper.createXMLCapBandResourceSelect(predicate, capability, band));
            return SQLQueryRI10ResourceXMLDoc(cmd);
        }

        [WebMethod(Description = "Returns VOResources with status=1 and 3: Input WHERE predicate for SQL Query")]
        public ivoa.net.ri1_0.server.Resource[] QueryFullVOR10Resource(string predicate)
        {
            string cmd = SQLHelper.TranslateOldSchemaQuery(SQLHelper.createFullXMLResourceSelect(predicate));
            return SQLQueryRI10Resource(cmd);
        }


		[WebMethod (Description="Returns OAI_DC: Input WHERE predicate for SQL Query")]
		public oai_dc.oai_dcType[] QueryOAIDC(string predicate, ArrayList queryParams = null)
		{
			string cmd = SQLHelper.TranslateOldSchemaQuery(SQLHelper.createBasicResourceSelect(predicate));	
			return SQLQueryOAIDC(cmd, queryParams);
		}

        public ivoa.net.ri1_0.server.Resource[] SQLQueryRI10Resource(string cmd)
        {
            SqlConnection conn = null;
            ivoa.net.ri1_0.server.Resource[] sr = new ivoa.net.ri1_0.server.Resource[0];
            cmd = SQLHelper.TranslateOldSchemaQuery(cmd);

            try
            {
                conn = new SqlConnection(sConnect);
                conn.Open();

                SqlDataAdapter sqlDA = new SqlDataAdapter(cmd, conn);
                DataSet ds = new DataSet();

                try
                {
                    sqlDA.Fill(ds);
                }
                catch (Exception e)
                {
                    if (errLog != null)
                    {
                        errLog.Log("Error creating data set: " + e.Message + "\n" +
                                    "    cmd: " + cmd + "\n");
                    }

                    return sr;
                }

                int ncount = ds.Tables[0].Rows.Count;
                ArrayList resList = new ArrayList();
                ivoa.net.ri1_0.server.Resource res = null;
                for (int i = 0; i < ncount; i++)
                {
                    DataRow dr = ds.Tables[0].Rows[i];
                    try
                    {
                        res = (ivoa.net.ri1_0.server.Resource)ResourceMaker.CreateRI10Resource(dr);
                    }
                    catch (Exception e)
                    {
                        if (errLog != null)
                        {
                            //common error - namespace issues with CEA types.
                            //todo -- get namespace stuff fixed for CEA. need input from astrogrid folks.
                            if (e.InnerException != null && e.InnerException.Message.Contains("CeaCapability"))
                                break;
                            if (e.InnerException != null && e.InnerException.Message.Contains("CeaApplication"))
                                break;


                            //try to just log the identifier. if identifier's what's wrong,
                            //then log the whole thing.
                            string dataString = dr.ItemArray[0].ToString();
                            int start = dataString.IndexOf("<identifier>");
                            int stop = dataString.IndexOf("</identifier>");
                            if (start > 0 && stop > 0)
                            {
                                dataString = dataString.Substring(start + 12, stop - start - 12).Trim();
                            }
                            string logMsg = "Error returning resource: " + e.Message + "\n" +
                                              "    query: " + cmd + "\n" +
                                              "    record: " + dataString + "\n";
                            if( e.InnerException != null )
                                logMsg += "    details: " + e.InnerException.Message + "\n";

                            errLog.Log(logMsg);
                        }

                        //gracefully skip this one.
                        res = null;
                    }
                    if (res != null)
                        resList.Add(res);
                }

                sr = (ivoa.net.ri1_0.server.Resource[])resList.ToArray(typeof(ivoa.net.ri1_0.server.Resource));
            }
            finally
            {
                conn.Close();
            }

            return sr;
        }

        //todo with c# date input/output formatting?
        private static string CleanUpOAIDates(string xml)
        {
            string tempString = xml;
            string newdateString = string.Empty;
            int index = -1;

            try
            {
                index = xml.IndexOf("created");
                int firstQuote = xml.IndexOf('\"', index);
                int secondQuote = xml.IndexOf('\"', firstQuote + 1);
                string createdString = xml.Substring(index, secondQuote - index + 1);
                index = xml.IndexOf("updated");
                firstQuote = xml.IndexOf('\"', index);
                secondQuote = xml.IndexOf('\"', firstQuote + 1);
                string updatedString = xml.Substring(index, secondQuote - index + 1);

                index = createdString.IndexOf('.');
                if (index > -1 )
                {
                    newdateString = createdString.Replace(createdString.Substring(index,
                        createdString.IndexOf("\"", index) - index), "Z");
                    tempString = tempString.Replace(createdString, newdateString);
                }
                else if (!createdString.Contains("Z") )
                {
                    string timeString = createdString.Substring(createdString.IndexOf("T"), 9);
                    newdateString = createdString.Replace(timeString, timeString + "Z");
                    tempString = tempString.Replace(createdString, newdateString);
                }

                index = updatedString.IndexOf('.');
                if (index > -1)
                {
                    newdateString = updatedString.Replace(updatedString.Substring(index,
                        updatedString.IndexOf("\"", index) - index), "Z");
                    tempString = tempString.Replace(updatedString, newdateString);
                }
                else if( !updatedString.Contains("Z") )
                {
                    string timeString = updatedString.Substring(updatedString.IndexOf("T"), 9);
                    newdateString = updatedString.Replace(timeString, timeString + "Z");
                    tempString = tempString.Replace(updatedString, newdateString);
                }
            }
            catch( Exception e )
            {
                tempString = xml;
                if (errLog != null)
                {
                    //try to just log the identifier. if identifier's what's wrong,
                    //then log the whole thing.
                    string dataString = xml;
                    int start = dataString.IndexOf("<identifier>");
                    int stop = dataString.IndexOf("</identifier>");
                    if (start > 0 && stop > 0)
                    {
                        dataString = dataString.Substring(start + 12, stop - start - 12).Trim();
                    }
                    errLog.Log(e.ToString() + " " + dataString);
                }
            }
            return tempString;
        }

        public System.Xml.XmlDocument[] SQLQueryRI10ResourceXMLDoc(string cmd, ArrayList queryParams = null)
        {
            System.Xml.XmlDocument[] docs = null;
            cmd = SQLHelper.TranslateOldSchemaQuery(cmd);

            using (SqlConnection conn = new SqlConnection(sConnect))
            {
                conn.Open();
                SqlCommand command = new SqlCommand();
                command.Connection = conn;
                command.CommandText = cmd;
                if(queryParams != null){
                    foreach(SqlParameter s in queryParams){
                        command.Parameters.Add(s);
                    }
                }
                command.Prepare();

                SqlDataAdapter sqlDA = new SqlDataAdapter();
                sqlDA.SelectCommand = command;
                DataSet ds = new DataSet();

                try
                {
                    sqlDA.Fill(ds);
                }
                catch (Exception e)
                {
                    if (errLog != null)
                    {
                        errLog.Log("Error creating data set: " + e.Message + "\n" +
                                    "    cmd: " + cmd + "\n");
                    }

                    return new System.Xml.XmlDocument[0];
                }

                int ncount = ds.Tables[0].Rows.Count;
                docs = new System.Xml.XmlDocument[ncount];
                DataRow dr;
                for (int i = 0; i < ncount; i++)
                {
                    dr = ds.Tables[0].Rows[i];
                    try
                    {
                        docs[i] = new System.Xml.XmlDocument();
                        docs[i].LoadXml(CleanUpOAIDates((string)dr[0]));
                    }
                    catch (Exception e)
                    {
                        if (errLog != null)
                        {
                            //try to just log the identifier. if identifier's what's wrong,
                            //then log the whole thing.
                            string dataString = dr.ItemArray[0].ToString();
                            int start = dataString.IndexOf("<identifier>");
                            int stop = dataString.IndexOf("</identifier>");
                            if (start > 0 && stop > 0)
                            {
                                dataString = dataString.Substring(start + 12, stop - start - 12).Trim();
                            }

                            errLog.Log("Error returning resource: " + e.Message + "\n" +
                                              "    query: " + cmd + "\n" +
                                              "    record: " + dataString + "\n");
                        }

                        //gracefully skip this one.
                        docs[i] = null;
                    }
                }
            }
            return docs;
        }

        private static void CreateResourceColumns(DataSet ds, int option, ref ivoa.altVOTable.VOTABLE vot)
        {
            ivoa.altVOTable.Table table = vot.RESOURCE[0].TABLE[0];

            table.Items = new object[25];
            for (int i = 0; i < table.Items.Length; ++i)
            {
                table.Items[i] = new Field();
                ((Field)table.Items[i]).datatype = dataType.@char;
            }

            ((Field)table.Items[0]).ID = "tags";
            ((Field)table.Items[0]).name = "categories";
            ((Field)table.Items[1]).ID = ((Field)table.Items[1]).name = "shortName";
            ((Field)table.Items[2]).ID = ((Field)table.Items[2]).name = "title";
            ((Field)table.Items[3]).ID = ((Field)table.Items[3]).name = "description";
            ((Field)table.Items[4]).ID = ((Field)table.Items[4]).name = "publisher";
            ((Field)table.Items[5]).ID = ((Field)table.Items[5]).name = "waveband";
            ((Field)table.Items[6]).ID = ((Field)table.Items[6]).name = "identifier";
            ((Field)table.Items[6]).ucd = "ID_MAIN";
            ((Field)table.Items[7]).ID = "updated";
            ((Field)table.Items[7]).name = "descriptionUpdated";
            ((Field)table.Items[8]).ID = ((Field)table.Items[8]).name = "subject";
            ((Field)table.Items[9]).ID = ((Field)table.Items[9]).name = "type";
            ((Field)table.Items[10]).ID = ((Field)table.Items[10]).name = "contentLevel";
            ((Field)table.Items[11]).ID = "regionOfRegard";
            ((Field)table.Items[11]).unit = "arcsec";
            ((Field)table.Items[11]).datatype = dataType.@float;
            ((Field)table.Items[11]).name = "typicalRegionSize";
            ((Field)table.Items[12]).ID = ((Field)table.Items[12]).name = "version";

            if (option == 2) //interface per row    
            {
                //difference from resource-per-row: insert here 'real' ID
                //<FIELD ID="resourceID" name="resourceID" datatype="char" arraysize="*"/>
                ((Field)table.Items[13]).ID = ((Field)table.Items[13]).name = "resourceID";

                ((Field)table.Items[14]).ID = ((Field)table.Items[14]).name = "capabilityClass";
                ((Field)table.Items[15]).ID = "capabilityStandardID";
                ((Field)table.Items[15]).name = "capabilityStandardID";
                ((Field)table.Items[16]).ID = ((Field)table.Items[16]).name = "capabilityValidationLevel";
                ((Field)table.Items[17]).ID = ((Field)table.Items[17]).name = "interfaceClass";
                ((Field)table.Items[18]).ID = ((Field)table.Items[18]).name = "interfaceVersion";
                ((Field)table.Items[19]).ID = ((Field)table.Items[19]).name = "interfaceRole";
                ((Field)table.Items[20]).ID = ((Field)table.Items[20]).name = "accessURL";
                //difference from resource-per-row: remove supported input parameters or add to xsl
                //((Field)table.Items[20]).ID = ((Field)table.Items[20]).name = "supportedInputParam";
            }
            else //default: resource per row
            {
                ((Field)table.Items[13]).ID = ((Field)table.Items[13]).name = "capabilityClass";
                ((Field)table.Items[14]).ID = "capabilityStandardID";
                ((Field)table.Items[14]).name = "capabilityStandardID";
                ((Field)table.Items[15]).ID = ((Field)table.Items[15]).name = "capabilityValidationLevel";
                ((Field)table.Items[16]).ID = ((Field)table.Items[16]).name = "interfaceClass";
                ((Field)table.Items[17]).ID = ((Field)table.Items[17]).name = "interfaceVersion";
                ((Field)table.Items[18]).ID = ((Field)table.Items[18]).name = "interfaceRole";
                ((Field)table.Items[19]).ID = ((Field)table.Items[19]).name = "accessURL";
                ((Field)table.Items[20]).ID = ((Field)table.Items[20]).name = "supportedInputParam";
            }

            ((Field)table.Items[21]).ID = "maxRadius";
            ((Field)table.Items[21]).datatype = dataType.@float;
            ((Field)table.Items[21]).name = "maxSearchRadius";
            ((Field)table.Items[22]).ID = ((Field)table.Items[22]).name = "maxRecords";
            ((Field)table.Items[22]).datatype = dataType.@int;
            ((Field)table.Items[23]).ID = "publisherID";
            ((Field)table.Items[23]).name = "publisherIdentifier";
            ((Field)table.Items[24]).ID = ((Field)table.Items[24]).name = "referenceURL";

            for(int i = 0; i < table.Items.Length; ++i ) 
            {
               if( ((Field)table.Items[i]).datatype == dataType.@char)
                   ((Field)table.Items[i]).arraysize = "*";
            }
        }

        //todo - 
        private static string addCategory(string current, DataRow row)
        {
            string type = Convert.ToString(row[14]);
            string cap = String.Empty;
            bool hasCap = false;
            string ifacecap = String.Empty;
            string result = "Generic Resource";

            //todo also interface, etc
            type = type.Substring(type.IndexOf(':') + 1 );
            if (row.ItemArray.Length > 15)
            {
                hasCap = true;
                cap = Convert.ToString(row[15]);
                cap = cap.Substring(cap.IndexOf(':') + 1 );
                ifacecap = Convert.ToString(row[18]);
                ifacecap = ifacecap.Substring(ifacecap.IndexOf(':') + 1);
            }
            if( type == "CatalogService" )
            {
                result = "Custom Service";
                if (hasCap)
                {
                    if (cap == "ConeSearch" || cap == "OpenSkyNode")
                        result = "Catalog";
                    else if (cap == "SimpleImageAccess")
                        result = "Images";
                    else if (cap == "SimpleSpectralAccess")
                        result = "Spectra";
                    else
                    {
                        if (ifacecap == "ParamHTTP")
                            result = "HTTP Request";
                        else if (ifacecap == "WebBrowser")
                            result = "Web Page";
                    }
                }
            }

            if (current == null)
                return '#' + result + '#';
            else if (current.Contains(result))
                return current;
            else
                return current + result + '#';
        }

        private static VOTABLE CreateResourceVOTable(DataSet ds, int option)
        {
            VOTABLE vot = new VOTABLE();
            try
            {
                vot.version = VOTABLEVersion.Item11;
                vot.RESOURCE = new ivoa.altVOTable.Resource[1];
                vot.RESOURCE[0] = new ivoa.altVOTable.Resource();
                vot.RESOURCE[0].type = ResourceType.results;

                //we're reducing this to one resource table.
                vot.RESOURCE[0].TABLE = new ivoa.altVOTable.Table[1];
                vot.RESOURCE[0].TABLE[0] = new ivoa.altVOTable.Table();

                CreateResourceColumns(ds, option, ref vot);

                vot.RESOURCE[0].TABLE[0].DATA = new Data();

                ArrayList trs = new ArrayList();
                 int sourceCount = ds.Tables[0].Rows.Count;
                bool badRow;
                for (int i = 0; i < sourceCount; ++i)
                {
                    badRow = false;

                    string rawtr = (string)ds.Tables[0].Rows[i][0];
                    int start = 0;
                    int columnindex = 0;
                    ArrayList TDs = new ArrayList();
                    while (start > -1 && badRow == false)
                    {
                        start = rawtr.IndexOf("<TD", start);
                        if (start > -1)
                        {
                            start += 4;
                            Td td = new Td();
                            if (rawtr[start] != '/')
                            {
                                int endIndex = rawtr.IndexOf("</TD>", start);
                                if (endIndex > start)
                                {
                                    string val = rawtr.Substring(start, endIndex - start);

                                    // We want to clean up accessURLs that don't end in ? or &
                                    // ((Field)table.Items[19]).ID = ((Field)table.Items[19]).name = "accessURL";
                                    if (columnindex == 19)
                                    {
                                        if (val.Length > 0 && (!val.Trim().EndsWith("?") && !val.Trim().EndsWith("&amp;")))
                                        {
                                            if (val.IndexOf('?') >= 0)
                                                val = val + "&amp;";
                                            else
                                                val = val + '?';
                                        }
                                    }

                                    td.Value = val;
                                }
                                else //generally from a description too long to import.
                                {
                                    td.Value = string.Empty;
                                    errLog.Log("Cannot un-cache row: " + rawtr);
                                    badRow = true;
                                }
                            }
                            TDs.Add(td);
                        }
                        ++columnindex;
                    }
                    //generally, again, bad rows are from a description too long to import.
                    if (!badRow) 
                    {
                        Tr tr = new Tr();
                        tr.TD = (Td[])TDs.ToArray(typeof(Td));
                        trs.Add(tr);
                    }
                }

                TableData destinationData = new TableData();
                destinationData.TR = new Tr[ds.Tables[0].Rows.Count];
                for (int i = 0; i < trs.Count; ++i)
                {
                    destinationData.TR[i] = (Tr)trs[i];
                }

                vot.RESOURCE[0].TABLE[0].DATA.Item = destinationData;
            }

            catch (Exception ex)
            {
                vot = new VOTABLE();
                errLog.Log(ex.ToString());
            }
            return vot;
        }

        public ivoa.altVOTable.VOTABLE QueryCapBandPredicateResourceCache(string predicate, string capability, string waveband, int option)
        {
            string cmd = SQLHelper.TranslateOldSchemaQuery(SQLHelper.createCapabilityWavebandPredicateSelectUsingCache(predicate, capability, waveband, option));
            return BuildVOTableResults(cmd, option);
        }

        public ivoa.altVOTable.VOTABLE SqlQueryRI10ResourceCache(string keywords, bool andKeys, int option)
        {
            string cmd = string.Empty;
            bool ordered = (keywords.Length > 0);
            if (option == 1)
                cmd = SQLHelper.getGetResourceCacheCmd(ordered);
            else
                cmd = SQLHelper.getGetInterfacesCacheCmd();

            string conditional = SQLHelper.createRankedResourceConditional(keywords, andKeys, true, option);
            cmd += conditional;

            return BuildVOTableResults(cmd, option);
        }

        private ivoa.altVOTable.VOTABLE BuildVOTableResults(string cachecmd, int option)
        {
            ivoa.altVOTable.VOTABLE table = new ivoa.altVOTable.VOTABLE();
            SqlConnection conn = null;
            DataSet resource = null;
            try
            {
                conn = new SqlConnection(sConnect);
                conn.Open();

                SqlDataAdapter sqlDA = new SqlDataAdapter(cachecmd, conn);
                resource = new DataSet();

                try
                {
                    sqlDA.Fill(resource);
                    table = CreateResourceVOTable(resource, option);
                }
                catch (Exception ex)
                {
                    //table = new ivoa.altVOTable.VOTABLE();
                    table = CreateErrorVOTable(ex.Message);
                }

            }
            catch (Exception ex)
            {
                //table = new ivoa.altVOTable.VOTABLE();
                table = CreateErrorVOTable(ex.Message);
            }
            finally
            {
                conn.Close();
            }


            return table;
        }

		//	[WebMethod (Description="Returns VOResources: Input Select Statement should return Resource Columns e.g. \n Select r.* from Resource r where maxRecords > 200")]
		public oai_dc.oai_dcType[] SQLQueryOAIDC(string cmd, ArrayList queryParams = null)
		{
			SqlConnection conn = null;
			oai_dc.oai_dcType[] odc = null;
            try
            {
                conn = new SqlConnection(sConnect);
                conn.Open();

                SqlCommand command = new SqlCommand();
                command.Connection = conn;
                command.CommandText = cmd;
                if (queryParams != null)
                {
                    foreach (SqlParameter s in queryParams)
                    {
                        command.Parameters.Add(s);
                    }
                }
                command.Prepare();
                SqlDataAdapter sqlDA = new SqlDataAdapter(command);

                DataSet ds = new DataSet();
                sqlDA.Fill(ds);
                int ncount = ds.Tables[0].Rows.Count;
                odc = new oai_dc.oai_dcType[ncount];
                for (int i = 0; i < ncount; i++)
                {
                    DataRow dr = ds.Tables[0].Rows[i];
                    odc[i] = (oai_dc.oai_dcType)registry.OAI_DC.CreateOAIDC(dr);
                }
            }
            catch (Exception e)
            {
				log.Error ("Error getting OAIDC records: " + e.Message);
				log.Error (e.StackTrace);
                odc = new oai_dc.oai_dcType[0];
            }

			finally 
			{
				conn.Close();
			}

			return odc;
		}

        protected static VOTABLE CreateErrorVOTable(string errortext)
        {
            VOTABLE vot = new VOTABLE();

            vot.version = VOTABLEVersion.Item11;
            vot.RESOURCE = new ivoa.altVOTable.Resource[1];
            vot.RESOURCE[0] = new ivoa.altVOTable.Resource();
            vot.RESOURCE[0].type = ResourceType.results;
            vot.RESOURCE[0].ID = "ERROR";
            vot.RESOURCE[0].name = errortext;

            return vot;
        }
   
    }


    //This is quick and dirty and very inefficient for frequent writes, but it doesn't hog a file handle, keeping users
    //from moving the file and suchlike. If usage increases, keep a  file handle,
    //use log4net, do something else, please.
    public class logfile
    {
        private static string location = (string)System.Configuration.ConfigurationManager.AppSettings["log_location"];
         public string fileName;

        public logfile(string fileName)
        {
            if (location != null)
            {
                if (location.EndsWith("\\"))
                    this.fileName = location + fileName;
                else
                    this.fileName = location + "\\" + fileName;
            }
        }

        public bool Log(string message)
        {
            if (this.fileName != null)
            {
                try
                {
                    using (System.IO.StreamWriter sw = new System.IO.StreamWriter(this.fileName, true))
                    {
                        sw.Write(DateTime.Now.ToString() + " -- " + message);
                        sw.Write("\n");
                        sw.Close();
                    }
                }
                catch (Exception)
                {
                    return false;
                }
            }
            else
                return false;

            return true;
        }
     }
}

/** log of changes
 * 
 *  $Log: Registry.asmx.cs,v $
 *  Revision 1.3  2006/02/28 17:09:49  grgreene
 *  delete for oai pub
 *
 *  Revision 1.2  2005/12/19 18:08:57  grgreene
 *  validationLEvel can edit now
 *
 *  Revision 1.1.1.1  2005/05/05 15:17:01  grgreene
 *  import
 *
 *  Revision 1.55  2005/05/05 14:59:01  womullan
 *  adding oai files
 *
 *  Revision 1.54  2004/12/07 20:08:32  womullan
 *   accessURL
 *
 *  Revision 1.53  2004/12/07 17:30:12  womullan
 *   interface code
 *
 *  Revision 1.52  2004/12/07 16:20:37  womullan
 *  keyword query
 *
 *  Revision 1.51  2004/11/29 20:01:02  womullan
 *  fixed keyword
 *
 *  Revision 1.50  2004/11/10 20:15:00  womullan
 *  added interface count
 *
 *  Revision 1.49  2004/11/09 21:19:28  womullan
 *   fixed relaitons
 *
 *  Revision 1.48  2004/11/09 21:16:08  womullan
 *  added relation get
 *
 *  Revision 1.47  2004/11/09 21:11:01  womullan
 *  added relation get
 *
 *  Revision 1.46  2004/11/05 18:45:28  womullan
 *  relations added
 *
 *  Revision 1.45  2004/11/01 18:30:16  womullan
 *  v0.10 upgrade
 *
 *  Revision 1.44  2004/08/12 15:18:33  womullan
 *  fixed replicator
 *
 *  Revision 1.43  2004/07/01 20:41:26  womullan
 *   new voresource tryout
 *
 *  Revision 1.42  2004/05/12 16:24:37  womullan
 *  fixed service examples and removed sqlquery* services
 *
 *  Revision 1.41  2004/04/15 16:31:54  womullan
 *  updated link
 *
 *  Revision 1.40  2004/04/05 18:17:35  womullan
 *   fixed type casts for MaxSearchRadius and MaxRecords
 *
 *  Revision 1.39  2004/04/02 15:19:54  womullan
 *   Type cast in simple resource
 *
 *  Revision 1.38  2004/03/31 17:28:26  womullan
 *  changes for new schema
 *
 *  Revision 1.37  2004/03/25 16:29:20  womullan
 *   contains for inverted index
 *
 *  Revision 1.36  2004/03/12 19:15:49  womullan
 *  added keyword search to form
 *
 *  Revision 1.35  2004/02/13 19:07:30  womullan
 *  update voresource and ws layout
 *


 *  Revision 1.34  2004/02/05 18:48:47  womullan
 *  added sqlquery and harvestedfromDate
 *
 *  Revision 1.33  2003/12/18 19:56:49  womullan
 *   Fixed Harvest for resumptionTOken
 *
 *  Revision 1.32  2003/12/18 19:45:18  womullan
 *  updated harvester
 *
 *  Revision 1.31  2003/12/16 21:17:50  womullan
 *  now returning voresource
 *
 *  Revision 1.30  2003/12/15 21:00:39  womullan
 *  relations and Harvested from added
 *
 *  Revision 1.29  2003/12/08 17:32:39  womullan
 *  parser almost working
 *
 *  Revision 1.28  2003/12/06 19:29:07  womullan
 *  all working insert update
 *
 *  Revision 1.27  2003/12/06 01:46:26  womullan
 *   insert working update on the way
 *
 *  Revision 1.26  2003/12/05 15:50:00  womullan
 *   new object maker
 *
 *  Revision 1.25  2003/12/05 15:29:37  womullan
 *   load flat updated with new fields
 *
 *  Revision 1.24  2003/12/05 13:41:41  womullan
 *   cone siap skynode insert working
 *
 *  Revision 1.23  2003/12/04 19:46:39  womullan
 *   now working for Resource
 *
 *  Revision 1.22  2003/12/03 23:00:15  womullan
 *   many mods to get SQL working
 *
 *  Revision 1.21  2003/12/02 21:57:01  womullan
 *   start of new schema
 *
 *  Revision 1.20  2003/07/16 16:23:47  womullan
 *  Failed to get harvest working as service
 *
 *  Revision 1.19  2003/07/01 13:47:40  womullan
 *  modified string enum lists to arrays
 *
 *  Revision 1.18  2003/06/26 19:34:35  womullan
 *  pages colours, size of params in SQL
 *
 *  Revision 1.17  2003/06/23 18:02:59  womullan
 *  referenceURL in DB now; code changed to work with it
 *
 *  Revision 1.16  2003/06/16 19:47:49  womullan
 *   many changes as discussed in meeting- new pages
 *
 *  Revision 1.15  2003/06/13 15:01:44  womullan
 *  added aspx page for updating registry
 *  added style sheet and fixed a few bugs
 *
 *  Revision 1.14  2003/06/02 15:30:08  womullan
 *   put roy back in
 *
 *  Revision 1.13  2003/06/02 15:28:07  womullan
 *   fixed format content level
 *
 *  Revision 1.12  2003/05/14 13:39:37  womullan
 *   added CACR harvest
 *
 *  Revision 1.11  2003/05/09 23:50:10  womullan
 *  fixed date probl
 *
 *  Revision 1.10  2003/05/09 23:05:35  womullan
 *  minor changes like format try catch for null
 *
 *  Revision 1.9  2003/05/09 21:24:57  womullan
 *   harvest more fields
 *
 * 
 **/ 
