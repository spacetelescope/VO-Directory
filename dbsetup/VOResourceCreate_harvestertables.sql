USE [VORegTAP]
GO

/*** Database creation script vor voresource 1.1. 03/19/2018

Creates harvester-related tables, only required if the VAO/STScI harvester service will be run against this database.

Related files:
	* VOResourceCreate Basic table generation for minimal database schema and search.
***/


/****** Object:  Table [dbo].[HarvesterLog]    Script Date: 04/01/2013 16:12:39 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[HarvesterLog](
	[ServiceURL] [nvarchar](100) NOT NULL,
	[date] [datetime] NOT NULL,
	[type] [nchar](10) NOT NULL,
	[status] [int] NULL,
	[message] [text] NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

GO
/****** Object:  Table [dbo].[Harvester]    Script Date: 3/18/2018  ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Harvester](
	[ServiceURL] [nvarchar](100) NOT NULL,
	[RegistryID] [nvarchar](100) NOT NULL,
	[DoHarvest] [bit] NOT NULL
) ON [PRIMARY]

GO
INSERT [dbo].[Harvester] ([ServiceURL], [RegistryID], [DoHarvest]) VALUES (N'http://rofr.ivoa.net/cgi-bin/oai.pl', N'ivo://ivoa.net/rofr', 0)
GO
INSERT [dbo].[Harvester] ([ServiceURL], [RegistryID], [DoHarvest]) VALUES (N'http://www.cadc-ccda.hia-iha.nrc-cnrc.gc.ca/reg/oai', N'ivo://cadc.nrc.ca/registry', 0)
GO
INSERT [dbo].[Harvester] ([ServiceURL], [RegistryID], [DoHarvest]) VALUES (N'http://gavo.aip.de/oai.xml', N'ivo://aip.gavo.org/__system__/services/registry', 0)
GO
INSERT [dbo].[Harvester] ([ServiceURL], [RegistryID], [DoHarvest]) VALUES (N'http://dc.zah.uni-heidelberg.de/oai.xml', N'ivo://org.gavo.dc/__system__/services/registry', 0)
GO
INSERT [dbo].[Harvester] ([ServiceURL], [RegistryID], [DoHarvest]) VALUES (N'http://registry.euro-vo.org/oai.jsp', N'ivo://esavo/registry', 0)
GO
INSERT [dbo].[Harvester] ([ServiceURL], [RegistryID], [DoHarvest]) VALUES (N'http://msslkk.mssl.ucl.ac.uk/mssl-registry/OAIHandlerv1_0', N'ivo://mssl.ucl.ac.uk/org.astrogrid.registry.RegistryService', 0)
GO
INSERT [dbo].[Harvester] ([ServiceURL], [RegistryID], [DoHarvest]) VALUES (N'http://vo.astronet.ru/cas/registry.php', N'ivo://astronet.ru/cas/registry', 0)
GO
INSERT [dbo].[Harvester] ([ServiceURL], [RegistryID], [DoHarvest]) VALUES (N'http://astrogrid.ast.cam.ac.uk/CASU-registry/OAIHandlerv1_0', N'ivo://uk.ac.cam.ast/org.astrogrid.registry.RegistryService', 0)
GO
INSERT [dbo].[Harvester] ([ServiceURL], [RegistryID], [DoHarvest]) VALUES (N'http://jvo.nao.ac.jp/publishingRegistry1.0/oai.pl', N'ivo://jvo/publishingregistry', 0)
GO
INSERT [dbo].[Harvester] ([ServiceURL], [RegistryID], [DoHarvest]) VALUES (N'http://nvo.ncsa.uiuc.edu/cgi-bin/reg10/oai.pl', N'ivo://nvo.ncsa/registry', 0)
GO
INSERT [dbo].[Harvester] ([ServiceURL], [RegistryID], [DoHarvest]) VALUES (N'https://data.csiro.au:443/astrogrid-registry/OAIHandlerv1_0?', N'ivo://au.csiro/org.astrogrid.registry.RegistryService', 0)
GO
INSERT [dbo].[Harvester] ([ServiceURL], [RegistryID], [DoHarvest]) VALUES (N'http://publishing-registry.roe.ac.uk:80/astrogrid-registry_v1_0/OAIHandlerv1_0', N'ivo://wfau.roe.ac.uk/org.astrogrid.registry.RegistryService', 0)
GO
INSERT [dbo].[Harvester] ([ServiceURL], [RegistryID], [DoHarvest]) VALUES (N'http://nvo.caltech.edu:8080/carnivore/cgi-bin/OAI-XML/carnivore/OAI.pl', N'ivo://nvo.caltech/registry', 0)
GO
INSERT [dbo].[Harvester] ([ServiceURL], [RegistryID], [DoHarvest]) VALUES (N'http://heasarc.gsfc.nasa.gov/cgi-bin/OAI2/XMLFile/nvo/oai.pl', N'ivo://nasa.heasarc/heasarc.xml', 0)
GO
INSERT [dbo].[Harvester] ([ServiceURL], [RegistryID], [DoHarvest]) VALUES (N'http://cdsweb.u-strasbg.fr/reg-bin/vizier/oai.pl', N'ivo://CDS.VizieR/registry', 0)
GO
INSERT [dbo].[Harvester] ([ServiceURL], [RegistryID], [DoHarvest]) VALUES (N'http://cdaftp.harvard.edu/oai', N'ivo://cxc.harvard.edu/registry', 0)
GO
INSERT [dbo].[Harvester] ([ServiceURL], [RegistryID], [DoHarvest]) VALUES (N'http://vao.stsci.edu/directory/oai.aspx', N'ivo://archive.stsci.edu/nvoregistry', 0)
GO
INSERT [dbo].[Harvester] ([ServiceURL], [RegistryID], [DoHarvest]) VALUES (N'http://nova.iafe.uba.ar/oai.xml', N'ivo://ar.nova/__system__/services/registry', 0)
GO
INSERT [dbo].[Harvester] ([ServiceURL], [RegistryID], [DoHarvest]) VALUES (N'http://voparis-registry.obspm.fr/vo/oai', N'ivo://vopdc/registry', 0)
GO
INSERT [dbo].[Harvester] ([ServiceURL], [RegistryID], [DoHarvest]) VALUES (N'http://irsa.ipac.caltech.edu/Publishing_Registry', N'ivo://irsa.ipac/registry', 0)
GO
INSERT [dbo].[Harvester] ([ServiceURL], [RegistryID], [DoHarvest]) VALUES (N'http://data.xao.ac.cn/oai.xml', N'ivo://xaovo/__system__/services/registry', 0)
GO
INSERT [dbo].[Harvester] ([ServiceURL], [RegistryID], [DoHarvest]) VALUES (N'http://helio.mssl.ucl.ac.uk/helio_registry/OAIHandlerv1_0', N'ivo://helio-vo.eu/org.astrogrid.registry.RegistryService', 0)
GO
INSERT [dbo].[Harvester] ([ServiceURL], [RegistryID], [DoHarvest]) VALUES (N'http://vo.bsdc.icranet.org/oai.xml', N'ivo://bsdc.icranet.org/__system__/services/registry', 0)
GO
INSERT [dbo].[Harvester] ([ServiceURL], [RegistryID], [DoHarvest]) VALUES (N'http://msslkk.mssl.ucl.ac.uk/registry_leicester/OAIHandlerv1_0', N'ivo://uk.ac.le.star/org.astrogrid.registry.RegistryService', 0)
GO
INSERT [dbo].[Harvester] ([ServiceURL], [RegistryID], [DoHarvest]) VALUES (N'http://astroweb.projects.phys.ucl.ac.uk:8000/oai.xml', N'ivo://astro.ucl.ac.uk/__system__/services/registry', 0)
GO
INSERT [dbo].[Harvester] ([ServiceURL], [RegistryID], [DoHarvest]) VALUES (N'http://vos2.asu.cas.cz/oai.xml', N'ivo://asu.cas.cz/__system__/services/registry', 0)
GO
INSERT [dbo].[Harvester] ([ServiceURL], [RegistryID], [DoHarvest]) VALUES (N'http://vespa-ae.oma.be/oai.xml', N'ivo://bira-iasb/__system__/services/registry', 0)
GO
INSERT [dbo].[Harvester] ([ServiceURL], [RegistryID], [DoHarvest]) VALUES (N'http://oirsa.cfa.harvard.edu:8080/oai.xml', N'ivo://cfa.tdc/__system__/services/registry', 0)
GO
INSERT [dbo].[Harvester] ([ServiceURL], [RegistryID], [DoHarvest]) VALUES (N'http://registry.china-vo.org/oai', N'ivo://China-VO/registry', 0)
GO
INSERT [dbo].[Harvester] ([ServiceURL], [RegistryID], [DoHarvest]) VALUES (N'https://vo.chivo.cl/oai.xml', N'ivo://chivo/__system__/services/registry', 0)
GO
INSERT [dbo].[Harvester] ([ServiceURL], [RegistryID], [DoHarvest]) VALUES (N'http://dachs.planet.fu-berlin.de/oai.xml', N'ivo://fu-berlin.planet.hrsc/__system__/services/registry', 0)
GO
INSERT [dbo].[Harvester] ([ServiceURL], [RegistryID], [DoHarvest]) VALUES (N'http://dorotka.ufa.cas.cz/oai.xml', N'ivo://iap/__system__/services/registry', 0)
GO
INSERT [dbo].[Harvester] ([ServiceURL], [RegistryID], [DoHarvest]) VALUES (N'http://epn1.epn-vespa.jacobs-university.de/oai.xml', N'ivo://jacobsuni/__system__/services/registry', 0)
GO
INSERT [dbo].[Harvester] ([ServiceURL], [RegistryID], [DoHarvest]) VALUES (N'http://vo.projet.latmos.ipsl.fr/oai.xml', N'ivo://latmos.ipsl/__system__/services/registry', 0)
GO
INSERT [dbo].[Harvester] ([ServiceURL], [RegistryID], [DoHarvest]) VALUES (N'http://sery.lmd.jussieu.fr/oai.xml', N'ivo://lmd.jussieu/__system__/services/registry', 0)
GO
INSERT [dbo].[Harvester] ([ServiceURL], [RegistryID], [DoHarvest]) VALUES (N'http://dc.zah.uni-heidelberg.de/purx/q/pmh/pubreg.xml', N'ivo://purx/registry', 0)
GO
INSERT [dbo].[Harvester] ([ServiceURL], [RegistryID], [DoHarvest]) VALUES (N'http://pvol2.ehu.eus:8083/oai.xml', N'ivo://pvol/__system__/services/registry', 0)
GO
INSERT [dbo].[Harvester] ([ServiceURL], [RegistryID], [DoHarvest]) VALUES (N'http://www.sao.ru/astrogrid-registry/OAIHandlerv1_0', N'ivo://sao.ru/org.astrogrid.registry.RegistryService', 0)
GO
INSERT [dbo].[Harvester] ([ServiceURL], [RegistryID], [DoHarvest]) VALUES (N'http://spectrum.iaa.es/oai.xml', N'ivo://spectrum.iaa/__system__/services/registry', 0)
GO
INSERT [dbo].[Harvester] ([ServiceURL], [RegistryID], [DoHarvest]) VALUES (N'http://thebe.gp.tohoku.ac.jp/oai.xml', N'ivo://tohoku.univ.jp/__system__/services/registry', 0)
GO
INSERT [dbo].[Harvester] ([ServiceURL], [RegistryID], [DoHarvest]) VALUES (N'http://epn-tap.oeaw.ac.at/oai.xml', N'ivo://vo-plasma.oeaw.ac.at/__system__/services/registry', 0)
GO
INSERT [dbo].[Harvester] ([ServiceURL], [RegistryID], [DoHarvest]) VALUES (N'http://vespa.labs.vu.nl/oai.xml', N'ivo://vovu.vu/__system__/services/registry', 0)
GO
INSERT [dbo].[Harvester] ([ServiceURL], [RegistryID], [DoHarvest]) VALUES (N'http://rcsed-vo.sai.msu.ru/oai.xml', N'ivo://voxastro.org/__system__/services/registry', 0)
GO
