using System;
using System.Collections;
using System.ComponentModel;
using System.Data;
using System.Web;
using System.Web.Services;
using System.Xml;
using System.Xml.Serialization;
using System.IO;
using System.Text;
using System.Data.SqlClient;
using oai;
using log4net;
using System.Globalization;

namespace registry
{
	/// <summary>
	/// OAI Services for STScI/JHU NVO Registry
	/// </summary>
 	///Current version
	///ID:		$Id: STOAI.asmx.cs,v 1.9 2006/02/28 17:09:49 grgreene Exp $
	///Revision:	$Revision: 1.9 $
	///Date:	$Date: 2006/02/28 17:09:49 $
	///
	[System.Web.Services.WebService(Namespace="http://www.openarchives.org/OAI/2.0/")]
	public class STOAI : System.Web.Services.WebService
	{
		private static readonly ILog log = LogManager.GetLogger(typeof(STOAI));
        private static int resumptionTokenLimit = Convert.ToInt32(System.Configuration.ConfigurationManager.AppSettings["resumptionTokenLimit"]);
        private static string registryIdentity = (string)System.Configuration.ConfigurationManager.AppSettings["registryIdentity"];
        private static string registryName = (string)System.Configuration.ConfigurationManager.AppSettings["registryName"];
        private static string registryEmail = (string)System.Configuration.ConfigurationManager.AppSettings["registryEmail"];

        // Accepted UTC formats for OAI-PMH protocol
        public static string ISO8601DateWithTime = "yyyy-MM-ddTHH:mm:ssZ";
        public static string ISO8601Date = "yyyy-MM-dd";
        static string[] dateFormats = {ISO8601Date,ISO8601DateWithTime};                               

        private static string rqtValue = string.Empty;
        private static string managedSet = "ivo_managed";

        public static string earliestDatestamp = "2000-01-01T00:00:00Z";

        private static ArrayList managedAuthorityNames = null;

		public STOAI()
		{
			//CODEGEN: This call is required by the ASP.NET Web Services Designer
			InitializeComponent();
			// make sure registry is inited
			new Registry();

            if( managedAuthorityNames == null ) {
                managedAuthorityNames = getManagedAuthorityNames();
                managedAuthorityNames.Sort();
            }

            rqtValue = HttpContext.Current.Request.Url.GetLeftPart(UriPartial.Authority) + HttpContext.Current.Request.ApplicationPath;
            rqtValue = rqtValue.ToLower() + "/oai.aspx";
		}

        private static ArrayList getManagedAuthorityNames()
        {
            OAIPMHtype oaiResp = GetIdentifyResponse();
            IdentifyType id = (IdentifyType)oaiResp.Items[0];
            XmlNodeList authorities = id.description[0].GetElementsByTagName("managedAuthority");
            ArrayList authorityNames = new ArrayList(authorities.Count);
            for (int i = 0; i < authorities.Count; ++i)
            {
                authorityNames.Add(authorities[i].InnerText);
            }
            return authorityNames;
        }

        private static bool IsManagedAuthority(string id)
        {
            if (id.Length <= 6) return false;
            string coreIdString = id.Substring(6); //after ivo://
            int indexSlash = coreIdString.IndexOf('/');
            if (indexSlash > 0) coreIdString = coreIdString.Substring(0, indexSlash);
            int authorityIndex = managedAuthorityNames.BinarySearch(coreIdString);
            return (authorityIndex >= 0);
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

		// WEB SERVICE OAI METHOD:  Identify
		// Returns identification attributes describing repository
		
		[WebMethod]
		public OAIPMHtype Identify()
		{
            return GetIdentifyResponse();
        }

        private static OAIPMHtype GetIdentifyResponse()
        {

			OAIPMHtype oaiT  = new OAIPMHtype();

			requestType rqT = new requestType();
			rqT.verb = verbType.Identify;
			rqT.verbSpecified = true;
			rqT.Value = rqtValue;
			oaiT.request = rqT;	

			IdentifyType idT = new IdentifyType();
            idT.repositoryName = registryName;
			idT.baseURL			= rqtValue;
			idT.protocolVersion	=IdentifyTypeProtocolVersion.Item20;
			idT.adminEmail		= new string[1];
            idT.adminEmail[0] = registryEmail;
			idT.earliestDatestamp= earliestDatestamp;
            idT.deletedRecord = deletedRecordType.persistent;
			idT.granularity		=granularityType.YYYYMMDDThhmmssZ;



            Registry reg = new Registry();
            XmlDocument[] docs = reg.QueryRIResourceXMLDoc(" ivoid = '" + registryIdentity + "' and rstat = 1");
            if (docs.Length > 0)
            {
                idT.description = new XmlElement[1];
                idT.description[0] = docs[0].DocumentElement;
            }

			oaiT.Items = new object[1];
			oaiT.Items[0] = idT;
			return oaiT;
		}

		// WEB SERVICE OAI METHOD:  RecordType
		// Returns detailed record structure		
		[WebMethod]
		public OAIPMHtype GetRecord(string identifier, string metadataPrefix)
		{
			OAIPMHtype oaiT  = new OAIPMHtype();

			requestType rqT = new requestType();
			rqT.verb = verbType.GetRecord;
			rqT.verbSpecified = true;
            rqT.Value = rqtValue;
            if (metadataPrefix.Length > 0)
                rqT.metadataPrefix = metadataPrefix;
            if (identifier.Length > 0)
                rqT.identifier = identifier;
			oaiT.request = rqT;	

			recordType recT = new recordType();
			GetRecordType grecT = new GetRecordType();

            recT.header = new headerType();
            recT.header.identifier = identifier;
            if (IsManagedAuthority(recT.header.identifier))
            {
                recT.header.setSpec = new string[1];
                recT.header.setSpec[0] = managedSet;
            }

            Registry reg = new Registry();
            if (metadataPrefix == "ivo_vor")
            {
                System.Xml.XmlDocument[] reses = reg.QueryRIResourceXMLDocAllResources("resource.ivoid='" + identifier + "'", true, true);
                if (reses.Length == 0 || reses[0] == null)
                    return makeError(OAIPMHerrorcodeType.idDoesNotExist, identifier);
                try
                {
                    recT.header.datestamp = reses[0].DocumentElement.Attributes["updated"].Value;
                    if (recT.header.datestamp.Contains("."))
                        recT.header.datestamp = recT.header.datestamp.Remove(recT.header.datestamp.LastIndexOf('.'));

                    if (reses[0].DocumentElement.Attributes["status"].Value.ToLower().CompareTo("deleted") == 0)
                    {
                        recT.header.status = statusType.deleted;
                        recT.header.statusSpecified = true;
                    }
                    else
                    {
                        recT.metadata = reses[0].DocumentElement;
                    }
                }
                catch (Exception)
                {
                    return makeError(OAIPMHerrorcodeType.idDoesNotExist, identifier);
                }
            }
            else if( metadataPrefix == "oai_dc")
            {
                try
                {
                    oai_dc.oai_dcType[] odc = reg.QueryOAIDC("status = 'active' and resource.ivoid='" + identifier + "'", null);
                    if (odc.Length == 0)
                        return makeError(OAIPMHerrorcodeType.idDoesNotExist, identifier);
                    XmlElement docElement = GetElementFromOAIDC(odc[0]);
                    recT.metadata = docElement;

                    recT.header.identifier = recT.metadata.GetElementsByTagName("identifier")[0].InnerXml;
                    recT.header.datestamp = recT.metadata.GetElementsByTagName("date")[0].InnerXml;

                    if (IsManagedAuthority(recT.header.identifier))
                        recT.header.setSpec = new string[2] { "ivo_vor", managedSet };
                    else
                        recT.header.setSpec = new string[1] { "ivo_vor" };
                }
                catch (Exception ex)
                {
                    return makeError(OAIPMHerrorcodeType.idDoesNotExist, identifier);
                }
            }

            oaiT.Items = new object[1];
            grecT.record = recT;
            oaiT.Items[0] = grecT;
 
			return oaiT;
		}

        public XmlElement GetElementFromXMLResource(ivoa.net.ri1_0.server.Resource vor)
        {
            XmlSerializer ser = new XmlSerializer(typeof(ivoa.net.ri1_0.server.Resource));
            StringBuilder sb = new StringBuilder();
            StringWriter sw = new StringWriter(sb);

            XmlSerializerNamespaces ns = new XmlSerializerNamespaces();
            ns.Add("", "http://www.ivoa.net/xml/RegistryInterface/v1.0");

            ser.Serialize(sw, vor, ns);
            sw.Close();

            XmlSerializer ser2 = new XmlSerializer(typeof(XmlElement));
            StringReader sr = new StringReader(sb.ToString());

            return (XmlElement)ser2.Deserialize(sr);
        }

		public XmlElement GetElementFromOAIDC(oai_dc.oai_dcType odc)
		{
			
			XmlSerializer ser = new XmlSerializer(typeof(oai_dc.oai_dcType));
			StringBuilder sb = new StringBuilder();
			StringWriter sw = new StringWriter(sb);

            XmlSerializerNamespaces xsn = new XmlSerializerNamespaces();
            xsn.Add("dc", "http://www.openarchives.org/OAI/2.0/oai_dc/");
            ser.Serialize(sw,odc, xsn);

			sw.Close();

			XmlSerializer ser2 = new XmlSerializer(typeof(XmlElement));
			StringReader sr = new StringReader(sb.ToString());
	
			return (XmlElement)ser2.Deserialize(sr);
		}

		// WEB SERVICE OAI METHOD:  ListIdentifiers
		// Returns detailed record structure		
		[WebMethod(Description="Returns list of identifying headers - OAI")]
		public OAIPMHtype ListIdentifiers(string metadataPrefix, string from, string until, string set, string resumptionToken)
		{
            //resumption tokens -- if we have one, what subset of this list do we return?
            ResumptionInformation incomingResumptionInfo = null;
            resumptionTokenType outgoingToken = new resumptionTokenType();
            ResumptionInformation outgoingResumptionInfo = new ResumptionInformation();
            int start = 0;
            int end = 0;
            DateTime? fromDate = null;
            DateTime? untilDate = null;
            if (from != null && !from.Equals(""))
            {
                fromDate = DateTime.ParseExact(from, dateFormats, CultureInfo.InvariantCulture, DateTimeStyles.None);
            }
            if (until != null && !until.Equals(""))
            {
                untilDate = DateTime.ParseExact(until, dateFormats, CultureInfo.InvariantCulture, DateTimeStyles.None);
            }

            //do we already have a token?
            DateTime tokenCreated = DateTime.MinValue;
            if (resumptionToken != null && resumptionToken.Length > 0)
            {
                incomingResumptionInfo = nvo.oai.oai.RetrieveValidResumptionToken(resumptionToken, true);
                if (incomingResumptionInfo != null)
                {
                    start =  incomingResumptionInfo.startIdx;
                    set = incomingResumptionInfo.set;
                    fromDate = incomingResumptionInfo.from;
                    untilDate = incomingResumptionInfo.until;
                    metadataPrefix = incomingResumptionInfo.metadataPrefix;
                    // What does this mean????
                    //if( incomingToken.expirationDateSpecified )
                    tokenCreated = incomingResumptionInfo.expirationDate.AddHours(-6).ToLocalTime();
                }
            }

            if (fromDate == null)
                fromDate = DateTime.Parse("1990-01-01");

			ArrayList arr = new ArrayList();
			ArrayList dateArr = new ArrayList();
            //ArrayList updateArr = new ArrayList();

            String strCmd = "select ivoid, [created], [updated]";
            strCmd += "from Resource where [updated] > @fromDate";
            if (untilDate != null)
                strCmd += " and [updated] < @untilDate";
            if (set == managedSet)
                strCmd += " and (harvestedFromID is null or harvestedFromID='' or harvestedFromID like '%STScI%') ";
            strCmd += " and [rstat] = 1";

            using (SqlConnection dbConn = new SqlConnection(Registry.sConnect))
            {
                dbConn.Open();
                SqlCommand command = new SqlCommand();
                command.Connection = dbConn;
                command.CommandText = strCmd;

                SqlParameter fromDateParam = new SqlParameter("@fromDate", SqlDbType.DateTime);
                fromDateParam.Value = fromDate;
                command.Parameters.Add(fromDateParam);

                if (untilDate != null)
                {
                    SqlParameter untilDateParam = new SqlParameter("@untilDate", SqlDbType.DateTime);
                    untilDateParam.Value = untilDate;
                    command.Parameters.Add(untilDateParam);
                }

                command.Prepare();
                using (SqlDataReader reader = command.ExecuteReader())
                {
                    while (reader.Read())
                    {
                        arr.Add(reader.GetString(0));
                        dateArr.Add(reader.GetDateTime(1));

                        //if( tokenCreated > DateTime.MinValue )
                        //    updateArr.Add(sdr.GetDateTime(2));
                    }
                }
            }

            if (arr.Count == 0)
            {
                return makeError(OAIPMHerrorcodeType.noRecordsMatch, String.Empty);
            }
            if (incomingResumptionInfo != null && Convert.ToInt32(incomingResumptionInfo.completeListSize) != arr.Count) 
                return makeError(OAIPMHerrorcodeType.badResumptionToken, "Change in query data.");

            //build OAI header
			OAIPMHtype oaiT  = new OAIPMHtype();
			requestType rqT = new requestType();
			rqT.verb = verbType.ListIdentifiers;
			rqT.verbSpecified = true;
			rqT.Value = rqtValue;
            rqT.from = fromDate.GetValueOrDefault().ToString(ISO8601Date);
            if (metadataPrefix != null && metadataPrefix.Length > 0)
                rqT.metadataPrefix = metadataPrefix;
            if (untilDate != null)
                rqT.until = untilDate.GetValueOrDefault().ToString(ISO8601Date);
            if (set != null && set == managedSet) //only one we're using
                rqT.set = set;
            oaiT.request = rqT;	


			ListIdentifiersType lisT = new ListIdentifiersType();
			lisT.header = new headerType[arr.Count];

			int iECount=0;
			int itest=0;


            end = Math.Min(start + resumptionTokenLimit, arr.Count);
            
            if ( (arr.Count > resumptionTokenLimit) && ( end < arr.Count) )
            {
                string tokenValue = GenerateResumptionTokenValue(fromDate, untilDate, set, metadataPrefix, start);
                DateTime expirationDate = System.DateTime.Now.AddHours(6).ToUniversalTime();
                outgoingResumptionInfo = new ResumptionInformation(tokenValue, expirationDate, fromDate, untilDate, set, metadataPrefix, end, arr.Count);
                outgoingToken = GenerateResumptionTokenOutput(tokenValue, start, expirationDate);

            }
			for (int ii = start; ii < end; ++ii)
			{
				itest++;
				lisT.header[ii] = new headerType();	
				
				try 
				{				
					lisT.header[ii].identifier = (string)arr[ii];					
                    lisT.header[ii].datestamp = GetOAIDatestamp((DateTime)dateArr[ii], granularityType.YYYYMMDDThhmmssZ);
                    if (IsManagedAuthority(lisT.header[ii].identifier))
                    {
                        lisT.header[ii].setSpec = new string[1];
                        lisT.header[ii].setSpec[0] = managedSet;
                    }
				}
				catch(Exception e)
				{
					iECount++;
					lisT.header[ii].identifier = e.ToString();			
				}
			}

            outgoingToken.completeListSize = arr.Count.ToString();
            
            if (outgoingToken.Value != null)
            {
                //resumptionTokenType nextToken = new resumptionTokenType(outgoingToken);
                //nextToken.cursor = Convert.ToString(Convert.ToInt32(outgoingToken.cursor) + resumptionTokenLimit);
                ResumptionInformationUtil.saveResumptionInformation(outgoingResumptionInfo);
                //nvo.oai.oai.SaveResumptionToken(nextToken);
            }
             

            lisT.resumptionToken = outgoingToken;
            oaiT.Items = new object[1];
			oaiT.Items[0] = lisT;
			return oaiT;
		}

		// WEB SERVICE OAI METHOD:  ListIdentifiers
		// Returns detailed record structure
	    [WebMethod(Description="Returns list of records - OAI")]
		public OAIPMHtype ListRecords(string from, string metadataPrefix, string until, string set, string resumptionToken)
		{
            //resumption tokens -- if we have one, what subset of this list do we return?
            ResumptionInformation incomingResumptionInfo = null;
            resumptionTokenType outgoingToken = new resumptionTokenType();
            ResumptionInformation outgoingResumptionInfo = new ResumptionInformation();
            int start = 0;
            int end = 0;
            DateTime? fromDate = null;
            DateTime? untilDate = null;
            // If date can't be parsed what is the proper response?
            if (from != null && !from.Equals(""))
            {
                try
                {
                    fromDate = DateTime.ParseExact(from, dateFormats, CultureInfo.InvariantCulture, DateTimeStyles.None);

                }
                catch(FormatException)
                {
                    fromDate = null;
                }
            }
            if (until != null && !until.Equals(""))
            {
                try
                {
                    untilDate = DateTime.ParseExact(until, dateFormats, CultureInfo.InvariantCulture, DateTimeStyles.None);

                }
                catch (FormatException)
                {
                    fromDate = null;
                }
            }

            //do we already have a token?
            if (resumptionToken != null && resumptionToken.Length > 0)
            {
                incomingResumptionInfo = nvo.oai.oai.RetrieveValidResumptionToken(resumptionToken, true);
                if (incomingResumptionInfo != null)
                {
                    start = incomingResumptionInfo.startIdx;
                    set = incomingResumptionInfo.set;
                    fromDate = incomingResumptionInfo.from;
                    untilDate = incomingResumptionInfo.until;
                    metadataPrefix = incomingResumptionInfo.metadataPrefix;
                }
            }
            
            if (fromDate == null)
                fromDate = DateTime.Parse("1990-01-01");

			OAIPMHtype oaiT  = new OAIPMHtype();

            //build OAI header
			requestType rqT = new requestType();
			rqT.verb = verbType.ListRecords;
			rqT.verbSpecified = true;
            rqT.Value = rqtValue;
            rqT.from = fromDate.Value.ToString(ISO8601Date);
            if( metadataPrefix != null && metadataPrefix.Length > 0 )
                rqT.metadataPrefix = metadataPrefix;
            if (untilDate != null)
                rqT.until = untilDate.Value.ToString(ISO8601Date);
            if (set != null && set == managedSet) //the only one we're using.
                rqT.set = set;
			oaiT.request = rqT;


            ArrayList paramList = new ArrayList();
            SqlParameter fromDateParam = new SqlParameter("@fromDate", SqlDbType.DateTime);
            fromDateParam.Value = fromDate;
            paramList.Add(fromDateParam);

            if (untilDate != null)
            {
                SqlParameter untilDateParam = new SqlParameter("@untilDate", SqlDbType.DateTime);
                untilDateParam.Value = untilDate;
                paramList.Add(untilDateParam);
            }

            String querystring = "[updated] >= @fromDate";
            if (untilDate != null)
                querystring += " and [updated] <= @untilDate";
            if( set == managedSet )
                querystring += " and (harvestedFromID is null or harvestedFromID='' or harvestedFromID like '%STScI%')";

			ListRecordsType lisT = new ListRecordsType();
			Registry reg = new Registry();

			if (metadataPrefix=="ivo_vor")
			{
                System.Xml.XmlDocument[] vod = reg.QueryRIResourceXMLDocAllResources(querystring, true, true, paramList);
                if (vod.Length == 0)
                {
                    return makeError(OAIPMHerrorcodeType.noRecordsMatch, String.Empty);
                }
                //no error checking on incoming completeListSize: according to spec this is an estimate.
                //Consistently use arr.count indexing and distrust incoming tokens.

                lisT.record = new recordType[vod.Length];
				
                end = Math.Min(start + resumptionTokenLimit, vod.Length);
                if ((vod.Length > resumptionTokenLimit) && (end < vod.Length))
                {
                    string tokenValue = GenerateResumptionTokenValue(fromDate, untilDate, set, metadataPrefix, start);
                    DateTime expirationDate = System.DateTime.Now.AddHours(6).ToUniversalTime();
                    outgoingResumptionInfo = new ResumptionInformation(tokenValue, expirationDate, fromDate, untilDate, set, metadataPrefix, end, vod.Length);
                    outgoingToken = GenerateResumptionTokenOutput(tokenValue, start, expirationDate);
                }

				for (int ii=start; ii< end; ++ii)
				{
 					lisT.record[ii] = new recordType();
					
					try 
					{
                        lisT.record[ii].metadata = vod[ii].DocumentElement;

						headerType ht = new headerType();
                        ht.identifier = vod[ii].GetElementsByTagName("identifier")[0].InnerXml;

                        ht.datestamp = vod[ii].DocumentElement.Attributes["updated"].Value;
						lisT.record[ii].header = ht;
		
                        if (vod[ii].DocumentElement.Attributes["status"].Value.ToLower().CompareTo("deleted") == 0 )
						{
							ht.status = statusType.deleted;
							ht.statusSpecified = true;
							lisT.record[ii].header.status = ht.status;
						}
                        if (IsManagedAuthority(ht.identifier))
                        {
                            ht.setSpec = new string[1];
                            ht.setSpec[0] = managedSet;
                        }
				    }
					catch(Exception e)
					{
						Console.Write(e);
					}
				}

                outgoingToken.completeListSize = vod.Length.ToString();

                if (outgoingToken.Value != null)
                {
                    ResumptionInformationUtil.saveResumptionInformation(outgoingResumptionInfo);
                }
                lisT.resumptionToken = outgoingToken;
			}
			else if (metadataPrefix=="oai_dc")
			{
                oai_dc.oai_dcType[] odc = reg.QueryOAIDC(querystring, paramList);
                if (odc.Length == 0)
                    return makeError(OAIPMHerrorcodeType.noRecordsMatch, String.Empty);

				lisT.record = new recordType[odc.Length];

                end = Math.Min(start + resumptionTokenLimit, odc.Length);
                if ((odc.Length > resumptionTokenLimit) && (end < odc.Length))
                {
                    string tokenValue = GenerateResumptionTokenValue(fromDate, untilDate, set, metadataPrefix, start);
                    DateTime expirationDate = System.DateTime.Now.AddHours(6).ToUniversalTime();
                    outgoingResumptionInfo = new ResumptionInformation(tokenValue, expirationDate, fromDate, untilDate, set, metadataPrefix, end, odc.Length);
                    outgoingToken = GenerateResumptionTokenOutput(tokenValue, start, expirationDate);
                }

                for (int ii = start; ii < end; ++ii)
				{
					lisT.record[ii] = new recordType();
					try 
					{
						lisT.record[ii].metadata = GetElementFromOAIDC(odc[ii]);

                        headerType ht = new headerType();
                        ht.identifier = lisT.record[ii].metadata.GetElementsByTagName("identifier")[0].InnerXml;
                        ht.datestamp = lisT.record[ii].metadata.GetElementsByTagName("date")[0].InnerXml;
                        if (IsManagedAuthority(ht.identifier))
                            ht.setSpec = new string[2] { "ivo_vor", managedSet };
                        else
                            ht.setSpec = new string[1] { "ivo_vor" };
                        lisT.record[ii].header = ht;
					}
					catch(Exception e)
					{
						Console.Write(e);
					}
				}

                outgoingToken.completeListSize = odc.Length.ToString();
                if (outgoingToken.Value != null)
                {
                    ResumptionInformationUtil.saveResumptionInformation(outgoingResumptionInfo);
                }
                lisT.resumptionToken = outgoingToken;
            }
				
			oaiT.Items = new object[1];
			oaiT.Items[0] = lisT;
			return oaiT;
		}

		// WEB SERVICE OAI METHOD:  ListMetaDataFormats
		// Returns format for VOService metadata
		[WebMethod(Description="Returns format for VOService metadata - OAI")]
		public OAIPMHtype ListMetadataFormats(string identifier)
		{
			OAIPMHtype oaiT  = new OAIPMHtype();

			requestType rqT = new requestType();
			rqT.verb = verbType.ListMetadataFormats;
			rqT.verbSpecified = true;
            rqT.Value = rqtValue;
            if (identifier.Length > 0)
                rqT.identifier = identifier;
			oaiT.request = rqT;

            //if no identifier given, then respond that we know these formats.
            int recordIVO_VOR = 1;
            int recordOAI_DC = 1;

            //if identification given, query for each format we know.
            //Since we're pulling this all from the same database, we're really only
            //checking to make sure we can correctly convert the data to the desired
            //format.
            if (identifier.Length > 0) 
            {
                Registry reg = new Registry();
                System.Xml.XmlDocument[] reses = reg.QueryRIResourceXMLDoc("resource.ivoid='" + identifier + "'");
                if (reses.Length == 0)
                    recordIVO_VOR = 0;

                oai_dc.oai_dcType[] odc = reg.QueryOAIDC("resource.ivoid='" + identifier + "'");
                if (odc.Length == 0)
                    recordOAI_DC = 0;
            }

            if (recordIVO_VOR == 0 && recordOAI_DC == 0)
            {
                return makeError(OAIPMHerrorcodeType.idDoesNotExist, identifier);
            }

            metadataFormatType[] metaF = new metadataFormatType[recordOAI_DC + recordIVO_VOR];
            if (recordIVO_VOR > 0)
            {
                metaF[0] = new metadataFormatType();
                //metaF[0].metadataNamespace = "http://www.ivoa.net/xml/VOResource/v0.10";
                metaF[0].metadataNamespace = "http://www.ivoa.net/xml/VOResource/v1.0";
                metaF[0].metadataPrefix = "ivo_vor";
                //metaF[0].schema = "http://www.ivoa.net/xml/VOResource/v0.10/VOResource-v0.10.xsd";
                metaF[0].schema = "http://www.ivoa.net/xml/VOResource/v1.0";
            }
            if (recordOAI_DC > 0)
            {
                metaF[recordIVO_VOR] = new metadataFormatType();
                metaF[recordIVO_VOR].metadataNamespace = "http://www.openarchives.org/OAI/2.0/oai_dc/";
                metaF[recordIVO_VOR].metadataPrefix = "oai_dc";
                metaF[recordIVO_VOR].schema = "http://www.openarchives.org/OAI/2.0/oai_dc.xsd";
            }
            oaiT.Items = new object[1];
            oaiT.Items[0] = metaF;

			return oaiT;
		}

		[WebMethod(Description="Returns format for VOService metadata - OAI")]
		public OAIPMHtype ListSets()
		{

			OAIPMHtype oaiT  = new OAIPMHtype();

			requestType rqT = new requestType();
			rqT.verb = verbType.ListSets;
			rqT.verbSpecified = true;
            rqT.Value = rqtValue;
			oaiT.request = rqT;	

			ListSetsType lsT = new ListSetsType();
			lsT.set = new setType[1];
            lsT.set[0] = new setType();
			lsT.set[0].setName = managedSet;
            lsT.set[0].setSpec = managedSet;
			
			oaiT.Items = new object[1];
			oaiT.Items[0] = lsT;


			return oaiT;
		}

        private OAIPMHtype makeError(OAIPMHerrorcodeType type, string str)
        {
            OAIPMHtype oaiT = new OAIPMHtype();

            requestType rqT = new requestType();
            rqT.Value = rqtValue;
            oaiT.request = rqT;

            OAIPMHerrorType oaiET = new OAIPMHerrorType();
            oaiET.Value = str;
            oaiET.code = type;

            oaiT.Items = new object[1];
            oaiT.Items[0] = oaiET;

            return oaiT;
        }

        [WebMethod(Description = "Returns error - OAI")]
        public OAIPMHtype makeBadVerb(string str)
        {
            return makeError(OAIPMHerrorcodeType.badVerb, str);
        }

        [WebMethod(Description = "Returns error - OAI")]
        public OAIPMHtype makeBadArg(string str)
        {
            return makeError(OAIPMHerrorcodeType.badArgument, str);
        }

        [WebMethod(Description = "Returns errors - OAI")]
        public OAIPMHtype makeMultipleErrors(string[] errorTypes, string[] errorValues)
        {
            OAIPMHtype oaiT = new OAIPMHtype();
            oaiT.Items = new object[errorValues.Length];

            for(int i = 0; i < errorValues.Length; ++i )
            {
                requestType rqT = new requestType();
                rqT.Value = rqtValue;
                oaiT.request = rqT;

                OAIPMHerrorType oaiET = new OAIPMHerrorType();
                oaiET.Value = errorValues[i];

                oaiET.code = (OAIPMHerrorcodeType)Enum.Parse(typeof(OAIPMHerrorcodeType), (String)errorTypes[i]);

                oaiT.Items[i] = oaiET;
            }

            return oaiT;
        }

        private static string buf2(int inpn)
        {
            string inp = "" + inpn;
            if (inp.Length < 2)
                return "0" + inp;
            else return inp;
        }

        // Should use c# DateTime conversion functions for this
        
        public static String GetOAIDatestamp(DateTime date, oai.granularityType granularity)
        {
            string datestring = date.Year.ToString() + "-" + buf2(date.Month) + "-" + buf2(date.Day);
            if( granularity == granularityType.YYYYMMDDThhmmssZ )
                datestring += "T" + buf2(date.Hour) + ":" + buf2(date.Minute) + ":" + buf2(date.Second) + "Z";

            return datestring;
        }
        
        public static string ConvertOAIDateToSQL(string oai)
        {
            try
            {
                String datetime = oai.Substring(5, 2) + '/' + oai.Substring(8, 2) + '/' + oai.Substring(0, 4);
                if (oai.IndexOf('T') > 0)
                {
                    datetime += ' ' + oai.Substring(11, 2) + ':' + oai.Substring(14, 2) + ':' + oai.Substring(17, 2);
                }
                return datetime;
            }
            catch (Exception) { return String.Empty;  }
        }

        string GenerateResumptionTokenValue(DateTime? fromDate, DateTime? untilDate, string set, string metadataPrefix, int? start)
        {
            StringBuilder tokenName = new StringBuilder();
            /*

            // We are using the format set!from!until!metadataPrefix!counter
            // but we no longer parse this token to get the values. Instead they are stored
            // in a database.
            if (set != null)
                tokenName.Append(set);
            tokenName.Append('!');
            // need to format date
            if (fromDate != null && fromDate.Value.CompareTo(DateTime.Parse("1990-01-01")) != 0)
                tokenName.Append(fromDate.Value.ToString("yyyy-MM-dd"));
            tokenName.Append('!');
            if (untilDate != null)
                tokenName.Append(untilDate.Value.ToString("yyyy-MM-dd"));
            tokenName.Append('!');
            tokenName.Append(metadataPrefix);
            tokenName.Append('!');
             */
            // Generate a "random" string to make the token unique
            Guid g = Guid.NewGuid();
            string gStr = Convert.ToBase64String(g.ToByteArray());
            gStr = gStr.Replace("=", "");
            gStr = gStr.Replace("+", "");
            tokenName.Append(gStr.Substring(0,10));
            return tokenName.ToString();

        }

        resumptionTokenType GenerateResumptionTokenOutput(string tokenValue, int cursor, DateTime expirationDate)
        {
            resumptionTokenType outtoken = new resumptionTokenType();


            outtoken.Value = tokenValue;
            outtoken.cursor = cursor.ToString();
            outtoken.expirationDate = expirationDate;
            outtoken.expirationDateSpecified = true;

            return outtoken;
        }
	}
}
