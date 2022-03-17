<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                 xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                 xmlns:sn="http://www.ivoa.net/xml/OpenSkyNode/v0.2"
                 xmlns:ssa="http://www.ivoa.net/xml/SSA/v1.1"
                 xmlns:sia="http://www.ivoa.net/xml/SIA/v1.1"
                 xmlns:slap="http://www.ivoa.net/xml/SLAP/v1.0"
                 xmlns:cs="http://www.ivoa.net/xml/ConeSearch/v1.0"
                 xmlns:vd="http://www.ivoa.net/xml/StandardRegExt/v1.0"
                 xmlns:tap="http://www.ivoa.net/xml/TAPRegExt/v1.0"
                 xmlns:vg="http://www.ivoa.net/xml/VORegistry/v1.0"
                 xmlns:vs="http://www.ivoa.net/xml/VODataService/v1.1"
                 xmlns:vr="http://www.ivoa.net/xml/VOResource/v1.0"
                 version="1.0">

  <xsl:output method="text"/>

  <!-- ################################################################ 
  -  Stylesheet input parameters
  -  ################################################################ -->

  <!--
     -  the schema name
     -->
  <xsl:param name="rr">rr</xsl:param>

  <!--
     -  if the input record was harvested, set this to the identifier of
     -  the registry it was harvested from.
     -
     - This is still used in validated-by
     -->
  <xsl:param name="harvestedFromID">
    <xsl:apply-templates
                       select="/child::processing-instruction('harvestInfo')"
                       mode="harvestinfo">
      <xsl:with-param name="attr">from.id</xsl:with-param>
    </xsl:apply-templates>
  </xsl:param>

  <!--
     -  the IVOA identifier of the harvesting registry (that is 
     -  assigning validation levels).  This is used to located and 
     -  extract the validation level assigned locally for inclusion in
     -  the main resource table
     -->
  <xsl:param name="localRegistryID">ivo://archive.stsci.edu/nvoregistry</xsl:param>

  <!--
     -  if the input record has a locally-set validationLevel at the resource 
     -  scope for performance in search results.  (deprecated)
     -->
  <xsl:param name="localValidationLevel"/>

  <!--
     -  a default resource validation level to record if one was not 
     -  assigned by this registry.
     -->
  <xsl:param name="defaultResourceValidationLevel">
    <xsl:choose>
      <xsl:when test="$localValidationLevel">
        <xsl:value-of select="$localValidationLevel"/>
      </xsl:when>
      <xsl:otherwise>2</xsl:otherwise>
    </xsl:choose>
  </xsl:param>

  <!-- ################################################################ 
  -  Document root:  set up the insert environment and load resource
  -  ################################################################ -->

  <!--
     -  set up the insert transaction, including the declaration variables
     -->
  <xsl:template match="/">
    <xsl:text> -- VOResource-to-database Converter 

declare @existingCopies smallint;
set @existingCopies=0;

declare @rrivoid varchar(max);
declare @rrcapseq smallint;
declare @rrifseq smallint;
declare @rrschemaseq smallint;
declare @rrtableseq smallint;

</xsl:text>

    <!-- remove any existing resource with the same identifier as this one -->
    <xsl:text>
    execute </xsl:text>
    <xsl:value-of select="$rr"/>
    <xsl:text>.deletedeprecatedresourcefromtapcache '</xsl:text>
    <xsl:value-of select="normalize-space(/*/identifier)"/>
    <xsl:text>', @existingCopies OUTPUT;

</xsl:text>

    <!-- load the resource: TAP cache only includes active resources -->
    <xsl:if test="normalize-space(*/@status) = 'active'">
      <xsl:apply-templates select="*"/>
    </xsl:if>
  </xsl:template>

  <!-- ################################################################ 
  -  Identify and handle Resource types
  -  ################################################################ -->

  <xsl:template match="*[identifier]" priority="-2">
    <!-- generic or unrecognized resource type; treat generically -->
    <xsl:apply-templates select="." mode="type_Resource"/>
  </xsl:template>

  <xsl:template match="*[substring-after(@xsi:type,':')='authority']">
    <xsl:apply-templates select="." mode="type_Authority"/>
  </xsl:template>

  <xsl:template match="*[substring-after(@xsi:type,':')='organisation']">
    <xsl:apply-templates select="." mode="type_Organisation"/>
  </xsl:template>

  <xsl:template match="*[substring-after(@xsi:type,':')='datacollection']">
    <xsl:apply-templates select="." mode="type_DataCollection"/>
  </xsl:template>

  <xsl:template match="*[capability]" priority="-1">
    <!-- unrecognized service; treat as a generic service -->
    <xsl:apply-templates select="." mode="type_Service"/>
  </xsl:template>
  <xsl:template match="*[substring-after(@xsi:type,':')='service']">
    <xsl:apply-templates select="." mode="type_Service"/>
  </xsl:template>

  <xsl:template match="*[substring-after(@xsi:type,':')='dataservice']">
    <xsl:apply-templates select="." mode="type_DataService"/>
  </xsl:template>

  <xsl:template match="*[substring-after(@xsi:type,':')='catalogservice']">
    <xsl:apply-templates select="." mode="type_CatalogService"/>
  </xsl:template>

  <!-- VODataService v1.0 compatibility -->
  <xsl:template match="*[substring-after(@xsi:type,':')='tableservice']">
    <xsl:apply-templates select="." mode="type_TableService"/>
  </xsl:template>

  <xsl:template match="*[substring-after(@xsi:type,':')='registry']">
    <xsl:apply-templates select="." mode="type_Registry"/>
  </xsl:template>

  <xsl:template match="*[substring-after(@xsi:type,':')='standard']">
    <xsl:apply-templates select="." mode="type_Standard"/>
  </xsl:template>
  <xsl:template match="*[substring-after(@xsi:type,':')='standardkeyenumeration']">
    <xsl:apply-templates select="." mode="type_Registry"/>
  </xsl:template>
  <xsl:template match="*[substring-after(@xsi:type,':')='servicestandard']">
    <xsl:apply-templates select="." mode="type_Registry"/>
  </xsl:template>

  <!-- ################################################################ 
  -  handle Resource types
  -  ################################################################ -->

  <!--
     - handle the generic Resource type
     -->
  <xsl:template match="*" mode="type_Resource">

    <xsl:text>-- core Resource metadata
</xsl:text>

    <xsl:apply-templates select="." mode="table_resource"/>
    <xsl:text>
</xsl:text>
  <xsl:apply-templates select="altIdentifier"/>

    <!-- Roles -->
    <xsl:apply-templates select="curation/publisher"/>
    <xsl:for-each select="curation/creator">
      <xsl:apply-templates select="curation/creator">
        <xsl:with-param name="seq" select="position()"/>
      </xsl:apply-templates>
    </xsl:for-each>
    <xsl:for-each select="curation/contributor">
      <xsl:apply-templates select=".">
        <xsl:with-param name="seq" select="position()"/>
      </xsl:apply-templates>
    </xsl:for-each>
    <xsl:for-each select="curation/creator">
      <xsl:apply-templates select=".">
        <xsl:with-param name="seq" select="position()"/>
      </xsl:apply-templates>
    </xsl:for-each>
    <xsl:for-each select="curation/contact">
      <xsl:apply-templates select=".">
        <xsl:with-param name="seq" select="position()"/>
      </xsl:apply-templates>
    </xsl:for-each>

    <!-- dates -->
    <xsl:text>
</xsl:text>
    <xsl:apply-templates select="curation/date" />

    <!-- subjects -->
    <xsl:text>
</xsl:text>
    <xsl:apply-templates select="content/subject" />

    <!-- relationships -->
    <xsl:text>
</xsl:text>
    <xsl:apply-templates select="content/relationship" />

    <!-- validation levels -->
    <xsl:text>
</xsl:text>
    <xsl:apply-templates select="validationLevel" />

    <!-- accessURLs outside of capabilities: dataCollections and documents -->
    <xsl:apply-templates select="accessURL" mode="loadResDetail"/>

    <!--<xsl:apply-templates select="endorsedVersion" mode="loadResDetail"/>-->
  
  </xsl:template>

  <!--
     -  handle the Authority resource
     -->
  <xsl:template match="*" mode="type_Authority">
    <!-- handle the core resource metadata -->
    <xsl:apply-templates select="." mode="type_Resource"/>

    <xsl:text>
-- Authority-specific metadata 
</xsl:text>

  <xsl:call-template name="loadDetail">
    <xsl:with-param name="val" select="managingOrg"/>
    <xsl:with-param name="detail_xpath">/managingOrg</xsl:with-param>
  </xsl:call-template>
  </xsl:template>
  
  <!--
     -  handle the Organization resource
     -->
  <xsl:template match="*" mode="type_Organisation">
    
    <!-- handle the core resource metadata -->
    <xsl:apply-templates select="." mode="type_Resource"/>
    
    <!--organisation-specific details-->
    <xsl:variable name="facility">
      <xsl:call-template name="mkstrval">
        <xsl:with-param name="valnodes" select="facility"/>
        <xsl:with-param name="asarray" select="true()"/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="instrument">
      <xsl:call-template name="mkstrval">
        <xsl:with-param name="valnodes" select="instrument"/>
        <xsl:with-param name="asarray" select="true()"/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:if test="facility">
      <xsl:call-template name="loadDetail">
        <xsl:with-param name="val" select="$facility"/>
        <xsl:with-param name="detail_xpath">/facility</xsl:with-param>
      </xsl:call-template>
    </xsl:if>
    <xsl:if test="instrument">
      <xsl:call-template name="loadDetail">
        <xsl:with-param name="val" select="$instrument"/>
        <xsl:with-param name="detail_xpath">/instrument</xsl:with-param>
      </xsl:call-template>
    </xsl:if>    
  </xsl:template>

  <!--
     -  handle the DataCollection resource
     -->
  <xsl:template match="*" mode="type_DataCollection">
    <!-- handle the core resource metadata -->
    <xsl:apply-templates select="." mode="type_Resource"/>

    <xsl:text>
-- DataCollection-specific metadata 
</xsl:text>
    
    <!--optional in RegTAP 1.1: also keep rights & rightsURI in the detail table-->
    <xsl:if test="rights">
      <xsl:apply-templates select="rights" mode="loadResDetail"/>
      <xsl:call-template name="loadDetail">
        <xsl:with-param name="val" select="rights/@rightsURI"/>
        <xsl:with-param name="detail_xpath">/rights/@rightsURI</xsl:with-param>
      </xsl:call-template>
    </xsl:if>

    <!-- add the DataCollection specific stuff -->
    <!-- augment the resource table -->

    <xsl:variable name="rights">
      <xsl:call-template name="mkstrval">
        <xsl:with-param name="valnodes" select="rights"/>
        <xsl:with-param name="asarray" select="true()"/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="format">
      <xsl:call-template name="mkstrval">
        <xsl:with-param name="valnodes" select="format"/>
        <xsl:with-param name="asarray" select="true()"/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="facility">
      <xsl:call-template name="mkstrval">
        <xsl:with-param name="valnodes" select="facility"/>
        <xsl:with-param name="asarray" select="true()"/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="instrument">
      <xsl:call-template name="mkstrval">
        <xsl:with-param name="valnodes" select="instrument"/>
        <xsl:with-param name="asarray" select="true()"/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:if test="format">
      <xsl:call-template name="loadDetail">
         <xsl:with-param name="val" select="$format"/>
        <xsl:with-param name="detail_xpath">/format</xsl:with-param>
      </xsl:call-template>
    </xsl:if>
    <xsl:if test="facility">
      <xsl:call-template name="loadDetail">
         <xsl:with-param name="val" select="$facility"/>
        <xsl:with-param name="detail_xpath">/facility</xsl:with-param>
      </xsl:call-template>
    </xsl:if>
    <xsl:if test="instrument">
      <xsl:call-template name="loadDetail">
        <xsl:with-param name="val" select="$instrument"/>
        <xsl:with-param name="detail_xpath">/instrument</xsl:with-param>
      </xsl:call-template>
    </xsl:if>
    <xsl:if test="coverage/footprint">
     <xsl:call-template name="loadDetail">
        <xsl:with-param name="val" select="coverage/footprint"/>
        <xsl:with-param name="detail_xpath">/coverage/footprint</xsl:with-param>
      </xsl:call-template>
        <xsl:if test="coverage/footprint/@ivo-id">
           <xsl:call-template name="loadDetail">
              <xsl:with-param name="val" select="coverage/footprint/@ivo-id"/>
              <xsl:with-param name="detail_xpath">/coverage/footprint/@ivo-id</xsl:with-param>
            </xsl:call-template>
         </xsl:if>
      </xsl:if>

    <xsl:text>UPDATE </xsl:text>
    <xsl:value-of select="$rr"/>
    <xsl:text>.resource SET 
        rights=</xsl:text>
    <xsl:value-of select="$rights"/>
    <xsl:text>,
       source_format=</xsl:text>
    <xsl:value-of select="$format"/>
   
    <xsl:if test="coverage/waveband">
      <xsl:text>,
       waveband=</xsl:text>
      <xsl:call-template name="mkstrval">
        <xsl:with-param name="valnodes" select="coverage/waveband"/>
        <xsl:with-param name="asarray" select="true()"/>
      </xsl:call-template>
    </xsl:if>

    <xsl:if test="coverage/regionOfRegard">
      <xsl:text>,
       region_of_regard=</xsl:text>
      <xsl:value-of select="normalize-space(coverage/regionOfRegard)"/>
    </xsl:if>

    <xsl:text>
    WHERE ivoid=@rrivoid;

</xsl:text>

    <xsl:apply-templates select="tableset"/>
    <xsl:apply-templates select="accessURL" mode="loadResDetail"/>

    <!-- catalog is for v1.0 compatibility -->
    <xsl:for-each select="catalog">
      <xsl:apply-templates select="." mode="vods10">
        <xsl:with-param name="seq" select="position()"/>
      </xsl:apply-templates>
    </xsl:for-each>

  </xsl:template>

  <!--
     -  handle the generic Service resource
     -->
  <xsl:template match="*" mode="type_Service">
    <!-- handle the core resource metadata -->
    <xsl:apply-templates select="." mode="type_Resource"/>

    <xsl:text>
-- Service metadata 
</xsl:text>

    <!-- add the Service-specific stuff -->
    <!-- augment the resource table -->
    <xsl:if test="rights">
            
      <!--optional in RegTAP 1.1: also keep rights & rightsURI in the detail table-->
      <xsl:apply-templates select="rights" mode="loadResDetail"/>
      <xsl:call-template name="loadDetail">
        <xsl:with-param name="val" select="rights/@rightsURI"/>
        <xsl:with-param name="detail_xpath">/rights/@rightsURI</xsl:with-param>
      </xsl:call-template>
        
      <xsl:variable name="rights">
        <xsl:call-template name="mkstrval">
          <xsl:with-param name="valnodes" select="rights"/>
          <xsl:with-param name="asarray" select="true()"/>
        </xsl:call-template>
      </xsl:variable>

      <xsl:text>UPDATE </xsl:text>
      <xsl:value-of select="$rr"/>
      <xsl:text>.resource SET 
        rights=</xsl:text>
      <xsl:value-of select="$rights"/>
      <xsl:text>
      WHERE ivoid=@rrivoid;

</xsl:text>
    </xsl:if>

    <!-- capabilities -->
    <xsl:for-each select="capability">
      <xsl:apply-templates select=".">
        <xsl:with-param name="seq" select="position()"/>
      </xsl:apply-templates>
    </xsl:for-each>
  </xsl:template>

  <!--
     -  handle the DataService resource
     -->
  <xsl:template match="*" mode="type_DataService">
    <!-- handle the service metadata -->
    <xsl:apply-templates select="." mode="type_Service"/>

    <!-- add the DataService specific stuff -->

    <xsl:variable name="facility">
      <xsl:call-template name="mkstrval">
        <xsl:with-param name="valnodes" select="facility"/>
        <xsl:with-param name="asarray" select="true()"/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="instrument">
      <xsl:call-template name="mkstrval">
        <xsl:with-param name="valnodes" select="instrument"/>
        <xsl:with-param name="asarray" select="true()"/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:if test="facility">
      <xsl:call-template name="loadDetail">
        <xsl:with-param name="val" select="$facility"/>
        <xsl:with-param name="detail_xpath">/facility</xsl:with-param>
      </xsl:call-template>
    </xsl:if>
    <xsl:if test="instrument">
      <xsl:call-template name="loadDetail">
        <xsl:with-param name="val" select="$instrument"/>
        <xsl:with-param name="detail_xpath">/instrument</xsl:with-param>
      </xsl:call-template>
    </xsl:if>
   
    <xsl:if test="coverage/footprint">
     <xsl:call-template name="loadDetail">
        <xsl:with-param name="val" select="coverage/footprint"/>
        <xsl:with-param name="detail_xpath">/coverage/footprint</xsl:with-param>
      </xsl:call-template>
        <xsl:if test="coverage/footprint/@ivo-id">
           <xsl:call-template name="loadDetail">
              <xsl:with-param name="val" select="coverage/footprint/@ivo-id"/>
              <xsl:with-param name="detail_xpath">/coverage/footprint/@ivo-id</xsl:with-param>
            </xsl:call-template>
         </xsl:if>
      </xsl:if>
        
    <xsl:if test="coverage/waveband">
      <xsl:text>UPDATE </xsl:text>
      <xsl:value-of select="$rr"/>
      <xsl:text>.resource SET 
       waveband=</xsl:text>
      <xsl:call-template name="mkstrval">
        <xsl:with-param name="valnodes" select="coverage/waveband"/>
        <xsl:with-param name="asarray" select="true()"/>
      </xsl:call-template>
      <xsl:text>
    WHERE ivoid=@rrivoid;
</xsl:text>
    </xsl:if>

    <xsl:if test="coverage/regionOfRegard">
      <xsl:text>UPDATE </xsl:text>
      <xsl:value-of select="$rr"/>
      <xsl:text>.resource SET 
       region_of_regard=</xsl:text>
      <xsl:value-of select="normalize-space(coverage/regionOfRegard)"/>
      <xsl:text>
    WHERE ivoid=@rrivoid;
</xsl:text>
    </xsl:if>
  </xsl:template>

  <!--
     -  handle the VODataService v1.0 TableService resource
     -->
  <xsl:template match="*" mode="type_TableService">
    <!-- handle the service metadata -->
    <xsl:apply-templates select="." mode="type_Service"/>

    <!-- add the DataService specific stuff -->
    <xsl:variable name="facility">
      <xsl:call-template name="mkstrval">
        <xsl:with-param name="valnodes" select="facility"/>
        <xsl:with-param name="asarray" select="true()"/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="instrument">
      <xsl:call-template name="mkstrval">
        <xsl:with-param name="valnodes" select="instrument"/>
        <xsl:with-param name="asarray" select="true()"/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:if test="facility">
      <xsl:call-template name="loadDetail">
        <xsl:with-param name="val" select="$facility"/>
        <xsl:with-param name="detail_xpath">/facility</xsl:with-param>
      </xsl:call-template>
    </xsl:if>
    <xsl:if test="instrument">
      <xsl:call-template name="loadDetail">
         <xsl:with-param name="val" select="$instrument"/>
        <xsl:with-param name="detail_xpath">/instrument</xsl:with-param>
      </xsl:call-template>
    </xsl:if>

    <!-- load the tables -->
    <xsl:if test="table">
      <xsl:apply-templates select="." mode="vods10"/>
    </xsl:if>
  </xsl:template>

  <!--
     -  handle the CatalogService resource
     -->
  <xsl:template match="*" mode="type_CatalogService">
    <!-- handle the service metadata -->
    <xsl:apply-templates select="." mode="type_DataService"/>

    <!-- add the CatalogService specific stuff -->
    <xsl:apply-templates select="tableset"/>

    <!-- support VODataService v1.0 version of CatalogService -->
    <xsl:if test="table">
      <xsl:apply-templates select="." mode="vods10"/>
    </xsl:if>
  </xsl:template>

  <!--
     -  handle the Registry resource
     -->
  <xsl:template match="*" mode="type_Registry">
    <!-- handle the service metadata -->
    <xsl:apply-templates select="." mode="type_Service"/>

    <!-- add the Registry specific stuff, stored as details -->
    <xsl:apply-templates select="full" mode="loadResDetail"/>
    <xsl:apply-templates select="managedAuthority" mode="loadResDetail"/>

  </xsl:template>

  <!--
     -  handle the Standard resource
     -->
  <xsl:template match="*" mode="type_Standard">
    <!-- handle the core resource metadata -->
    <xsl:apply-templates select="." mode="type_Resource"/>

    <xsl:text>-- Add Standards-specific metadata
</xsl:text>

    <xsl:apply-templates select="endorsedVersion" mode="loadResDetail"/>
      
     <xsl:apply-templates select="schema/@namespace" mode="loadResDetail">
      <xsl:with-param name="val">
        <xsl:value-of select="schema/@namespace"/>
      </xsl:with-param>
      <xsl:with-param name="attributePath">
        <xsl:value-of select="'/schema/@namespace'"/>
      </xsl:with-param>
    </xsl:apply-templates>
    <xsl:apply-templates select="deprecated" mode="loadResDetail"/>
  
  </xsl:template>


  <!-- ################################################################ 
  -  handle roles 
  -  ################################################################ -->

  <!--
     -  handle the publisher
     -->
  <xsl:template match="publisher">
    <xsl:call-template name="loadRole">
      <xsl:with-param name="name" select="."/>
      <xsl:with-param name="ivoid" select="@ivo-id"/>
      <xsl:with-param name="utype">publisher</xsl:with-param>
    </xsl:call-template>
  </xsl:template>

  <!--
     -  handle a creator
     -->
  <xsl:template match="creator">
    <xsl:param name="seq" select="1"/>
    <xsl:apply-templates select="altIdentifier"/>
    <xsl:call-template name="loadRole">
      <xsl:with-param name="name" select="name"/>
      <xsl:with-param name="ivoid" select="name/@ivo-id"/>
      <xsl:with-param name="logo" select="logo"/>
      <xsl:with-param name="seq" select="$seq"/>
      <xsl:with-param name="utype">creator</xsl:with-param>
    </xsl:call-template>
  </xsl:template>

  <!--
     -  handle a contributor
     -->
  <xsl:template match="contributor">
    <xsl:param name="seq" select="1"/>
    <xsl:call-template name="loadRole">
      <xsl:with-param name="name" select="."/>
      <xsl:with-param name="ivoid" select="@ivo-id"/>
      <xsl:with-param name="seq" select="$seq"/>
      <xsl:with-param name="utype">contributor</xsl:with-param>
    </xsl:call-template>
  </xsl:template>

  <!--
     -  handle a contact
     -->
  <xsl:template match="contact">
    <xsl:param name="seq" select="1"/>
    <xsl:call-template name="loadRole">
      <xsl:with-param name="name" select="name"/>
      <xsl:with-param name="ivoid" select="name/@ivo-id"/>
      <xsl:with-param name="address" select="address"/>
      <xsl:with-param name="email" select="email"/>
      <xsl:with-param name="telephone" select="telephone"/>
      <xsl:with-param name="seq" select="$seq"/>
      <xsl:with-param name="utype">contact</xsl:with-param>
    </xsl:call-template>
  </xsl:template>

  <!--
     -  load a record into the role table
     -->
  <xsl:template name="loadRole">
    <xsl:param name="name"/>
    <xsl:param name="ivoid"/>
    <xsl:param name="seq" select="1"/>
    <xsl:param name="address"/>
    <xsl:param name="email"/>
    <xsl:param name="telephone"/>
    <xsl:param name="logo"/>
    <xsl:param name="utype"/>

    <xsl:text>INSERT INTO </xsl:text>
    <xsl:value-of select="$rr"/>
    <xsl:text>.res_role (
      ivoid, base_role,
      role_name</xsl:text>
    <xsl:if test="$ivoid != ''">
      <xsl:text>,
      role_ivoid</xsl:text>
    </xsl:if>
    <xsl:if test="$address != ''">
      <xsl:text>,
      street_address</xsl:text>
    </xsl:if>
    <xsl:if test="$email != ''">
      <xsl:text>,
      email</xsl:text>
    </xsl:if>
    <xsl:if test="$telephone != ''">
      <xsl:text>,
      telephone</xsl:text>
    </xsl:if>
    <xsl:if test="$logo != ''">
      <xsl:text>,
      logo</xsl:text>
    </xsl:if>
    <xsl:text>
    ) VALUES (
      @rrivoid, </xsl:text>
    <xsl:call-template name="mkstrval">
      <xsl:with-param name="valnodes" select="$utype"/>
    </xsl:call-template>
    <xsl:text>,
      </xsl:text>
    <xsl:call-template name="mkstrval">
      <xsl:with-param name="valnodes" select="$name"/>
      <xsl:with-param name="notnull" select="true()"/>
    </xsl:call-template>

    <xsl:if test="$ivoid != ''">
      <xsl:text>,
      </xsl:text>
      <xsl:call-template name="mkstrval">
        <xsl:with-param name="valnodes" select="$ivoid"/>
      </xsl:call-template>
    </xsl:if>

    <xsl:if test="$address != ''">
      <xsl:text>,
      </xsl:text>
      <xsl:call-template name="mkstrval">
        <xsl:with-param name="valnodes" select="$address"/>
      </xsl:call-template>
    </xsl:if>

    <xsl:if test="$email != ''">
      <xsl:text>,
      </xsl:text>
      <xsl:call-template name="mkstrval">
        <xsl:with-param name="valnodes" select="$email"/>
      </xsl:call-template>
    </xsl:if>

    <xsl:if test="$telephone != ''">
      <xsl:text>,
      </xsl:text>
      <xsl:call-template name="mkstrval">
        <xsl:with-param name="valnodes" select="$telephone"/>
      </xsl:call-template>
    </xsl:if>

    <xsl:if test="$logo != ''">
      <xsl:text>,
      </xsl:text>
      <xsl:call-template name="mkstrval">
        <xsl:with-param name="valnodes" select="$logo"/>
      </xsl:call-template>
    </xsl:if>

    <xsl:text>
    );
</xsl:text>
  </xsl:template>

  <!-- ################################################################ 
  -  handle other resource sub-structure
  -  ################################################################ -->

  <!--
     -  handle a subject
     -->
  <xsl:template match="subject">
    <xsl:if test="string-length(normalize-space(.)) &gt; 0">
      <xsl:text>INSERT INTO </xsl:text>
      <xsl:value-of select="$rr"/>
      <xsl:text>.res_subject (
        ivoid, res_subject
      ) VALUES (
        @rrivoid, </xsl:text>
      <xsl:call-template name="mkstrval">
        <xsl:with-param name="valnodes" select="."/>
      </xsl:call-template>
      <xsl:text>
      );
</xsl:text>
    </xsl:if>
  </xsl:template>

  <!--
     -  handle a relationship (RegTAP 1.1)
     -->
  <xsl:template match="relationship">
    <xsl:variable name="type" select="relationshipType"/>

    <xsl:for-each select="relatedResource">
      <xsl:text>INSERT INTO </xsl:text>
      <xsl:value-of select="$rr"/>
      <xsl:text>.relationship (
        ivoid, relationship_type, related_id,
        related_name
      ) VALUES (
        @rrivoid, </xsl:text>
      <xsl:call-template name="convertrelationshiptype">
        <xsl:with-param name="valnodes" select="$type"/>
      </xsl:call-template>
      <xsl:text>, </xsl:text>
      <xsl:call-template name="mkstrval">
        <xsl:with-param name="valnodes" select="@ivo-id"/>
      </xsl:call-template>
      <xsl:text>, 
</xsl:text>
      <xsl:call-template name="mkstrval">
        <xsl:with-param name="valnodes" select="."/>
        <xsl:with-param name="notnull" select="true()"/>
      </xsl:call-template>
      <xsl:text>
      );
</xsl:text>
    </xsl:for-each>
  </xsl:template>

  <!--
     -  handle a date (RegTAP 1.1)
     -->
  <xsl:template match="date">
    <xsl:param name="resrole">
      <xsl:choose>
        <xsl:when test="normalize-space(@role)!=''">
          <xsl:value-of select="@role"/>
        </xsl:when>
        <xsl:otherwise>Collected</xsl:otherwise>
      </xsl:choose>
    </xsl:param>

    <xsl:if test="string-length(normalize-space(.)) &gt; 0">
      <xsl:text>INSERT INTO </xsl:text>
      <xsl:value-of select="$rr"/>
      <xsl:text>.res_date (
        ivoid, date_value, value_role
      ) VALUES (
        @rrivoid, </xsl:text>
      <xsl:call-template name="mkdateval">
        <xsl:with-param name="valnodes" select="."/>
      </xsl:call-template>
      <xsl:text>, </xsl:text>
      <xsl:call-template name="convertdaterole">
        <xsl:with-param name="valnodes" select="$resrole"/>
      </xsl:call-template>
      <xsl:text>
      );
</xsl:text>
    </xsl:if>
  </xsl:template>
  
  <!--
     -  handle an alternate identifier
     -->
  <xsl:template match="altIdentifier">
    <xsl:if test="string-length(normalize-space(.)) &gt; 0">
      <xsl:text>INSERT INTO </xsl:text>
      <xsl:value-of select="$rr"/>
      <xsl:text>.alt_identifier (
        ivoid, alt_identifier
      ) VALUES (
        @rrivoid, </xsl:text>
      <xsl:call-template name="mkstrval">
        <xsl:with-param name="valnodes" select="."/>
      </xsl:call-template>
      <xsl:text>
      );

</xsl:text>
    </xsl:if>
  </xsl:template>  
  

  <!-- ################################################################ 
  -  handle capabilities: determine type and load
  -  ################################################################ -->

  <!--
     -  handle a generic capability
     -->
  <xsl:template match="capability" priority="-2">
    <xsl:param name="seq" select="1"/>
    <xsl:apply-templates select="." mode="type_Capability">
      <xsl:with-param name="seq" select="$seq"/>
    </xsl:apply-templates>
  </xsl:template>

  <xsl:template
       match="capability[substring-after(@xsi:type,':')='conesearch']">
    <xsl:param name="seq" select="1"/>
    <xsl:apply-templates select="." mode="type_ConeSearch">
      <xsl:with-param name="seq" select="$seq"/>
    </xsl:apply-templates>
  </xsl:template>

  <xsl:template
       match="capability[substring-after(@xsi:type,':')='simpleimageaccess']">
    <xsl:param name="seq" select="1"/>
    <xsl:apply-templates select="." mode="type_SIA">
      <xsl:with-param name="seq" select="$seq"/>
    </xsl:apply-templates>
  </xsl:template>

  <xsl:template
     match="capability[substring-after(@xsi:type,':')='simplespectralaccess']">
    <xsl:param name="seq" select="1"/>
    <xsl:apply-templates select="." mode="type_SSA">
      <xsl:with-param name="seq" select="$seq"/>
    </xsl:apply-templates>
  </xsl:template>

  <xsl:template
     match="capability[substring-after(@xsi:type,':')='protospectralsccess']">
    <xsl:param name="seq" select="1"/>
    <xsl:apply-templates select="." mode="type_SSA">
      <xsl:with-param name="seq" select="$seq"/>
      <xsl:with-param name="base">PSSA_</xsl:with-param>
    </xsl:apply-templates>
  </xsl:template>

  <xsl:template
       match="capability[substring-after(@xsi:type,':')='simplelineaccess']">
    <xsl:param name="seq" select="1"/>
    <xsl:apply-templates select="." mode="type_SLAP">
      <xsl:with-param name="seq" select="$seq"/>
    </xsl:apply-templates>
  </xsl:template>

  <xsl:template
       match="capability[substring-after(@xsi:type,':')='tableaccess']">
    <xsl:param name="seq" select="1"/>
    <xsl:apply-templates select="." mode="type_TAP">
      <xsl:with-param name="seq" select="$seq"/>
    </xsl:apply-templates>
  </xsl:template>

  <!-- ################################################################ 
  -  handle Capability types
  -  ################################################################ -->

  <xsl:template match="capability" mode="type_Capability">
    <xsl:param name="seq" select="1"/>
    <xsl:param name="name" select="string($seq)"/>

    <xsl:text>SET @rrcapseq = </xsl:text>
    <xsl:value-of select="$seq"/>
    <xsl:text>;
</xsl:text>

    <xsl:apply-templates select="." mode="table_capability">
      <xsl:with-param name="name" select="$name"/>
    </xsl:apply-templates>

    <xsl:apply-templates select="validationLevel" />

    <xsl:for-each select="interface">
      <xsl:apply-templates select=".">
        <xsl:with-param name="seq" select="position()"/>
      </xsl:apply-templates>
    </xsl:for-each>
    
    <xsl:apply-templates select="interface/testQueryString" mode="loadTQSDetail"/>

    <xsl:text>
</xsl:text>
  </xsl:template>

  <xsl:template match="capability" mode="type_ConeSearch">
    <xsl:param name="seq" select="1"/>
    <xsl:param name="name" select="concat('ConeSearch_',string($seq))"/>

    <xsl:apply-templates select="." mode="type_Capability">
      <xsl:with-param name="seq" select="$seq"/>
      <xsl:with-param name="name" select="$name"/>
    </xsl:apply-templates>

    <xsl:apply-templates select="maxSR" mode="loadCapDetail"/>
    <xsl:apply-templates select="verbosity" mode="loadCapDetail"/>
    <xsl:apply-templates select="maxRecords" mode="loadCapDetail"/>

    <xsl:apply-templates select="testQuery/ra" mode="loadTQDetail"/>
    <xsl:apply-templates select="testQuery/dec" mode="loadTQDetail"/>
    <xsl:apply-templates select="testQuery/sr" mode="loadTQDetail"/>
    <xsl:apply-templates select="testQuery/catalog" mode="loadTQDetail"/>
  
    <xsl:apply-templates select="interface/testQueryString" mode="loadTQSDetail"/>
  
  </xsl:template>

  <xsl:template match="capability" mode="type_SIA">
    <xsl:param name="seq" select="1"/>
    <xsl:param name="name" select="concat('SIA_',string($seq))"/>

    <xsl:apply-templates select="." mode="type_Capability">
      <xsl:with-param name="seq" select="$seq"/>
      <xsl:with-param name="name" select="$name"/>
    </xsl:apply-templates>

    <xsl:apply-templates select="imageServiceType" mode="loadCapDetail"/>

    <xsl:apply-templates select="maxQueryRegionSize/lat" mode="loadCapDetail">
      <xsl:with-param name="subtype">maxQueryRegionSize.lat</xsl:with-param>
    </xsl:apply-templates>
    <xsl:apply-templates select="maxQueryRegionSize/long" mode="loadCapDetail">
      <xsl:with-param name="subtype">maxQueryRegionSize.long</xsl:with-param>
    </xsl:apply-templates>

    <xsl:apply-templates select="maxImageExtent/lat" mode="loadCapDetail">
      <xsl:with-param name="subtype">maxImageExtent.lat</xsl:with-param>
    </xsl:apply-templates>
    <xsl:apply-templates select="maxImageExtent/long" mode="loadCapDetail">
      <xsl:with-param name="subtype">maxImageExtent.long</xsl:with-param>
    </xsl:apply-templates>

    <xsl:apply-templates select="maxFileSize" mode="loadCapDetail"/>
    <xsl:apply-templates select="maxRecords" mode="loadCapDetail"/>

    <xsl:apply-templates select="maxImageSize" />

    <xsl:apply-templates select="testQuery/pos/long" mode="loadTQDetail">
      <xsl:with-param name="subtype">pos.long</xsl:with-param>
    </xsl:apply-templates>
    <xsl:apply-templates select="testQuery/pos/lat" mode="loadTQDetail">
      <xsl:with-param name="subtype">pos.lat</xsl:with-param>
    </xsl:apply-templates>

    <xsl:apply-templates select="testQuery/size/long" mode="loadTQDetail">
      <xsl:with-param name="subtype">size.long</xsl:with-param>
    </xsl:apply-templates>
    <xsl:apply-templates select="testQuery/size/lat" mode="loadTQDetail">
      <xsl:with-param name="subtype">size.lat</xsl:with-param>
    </xsl:apply-templates>

    <xsl:apply-templates select="testQuery/verb"   mode="loadTQDetail"/>
    <xsl:apply-templates select="testQuery/extras" mode="loadTQDetail"/>
  
    <xsl:apply-templates select="interface/testQueryString" mode="loadTQSDetail"/>
  </xsl:template>

  <xsl:template match="capability" mode="type_SSA">
    <xsl:param name="seq" select="1"/>
    <xsl:param name="base">SSA_</xsl:param>
    <xsl:param name="name" select="concat($base,string($seq))"/>

    <xsl:apply-templates select="." mode="type_Capability">
      <xsl:with-param name="seq" select="$seq"/>
      <xsl:with-param name="name" select="$name"/>
    </xsl:apply-templates>

    <xsl:apply-templates select="complianceLevel" mode="loadCapDetail"/>
    <xsl:apply-templates select="dataSource" mode="loadCapDetail"/>
    <xsl:apply-templates select="creationType" mode="loadCapDetail"/>
    <xsl:apply-templates select="supportedFrame" mode="loadCapDetail"/>
    <xsl:apply-templates select="maxSearchRadius" mode="loadCapDetail"/>
    <xsl:apply-templates select="maxRecords" mode="loadCapDetail"/>
    <xsl:apply-templates select="defaultMaxRecords" mode="loadCapDetail"/>
    <xsl:apply-templates select="maxAperture" mode="loadCapDetail"/>
    <xsl:apply-templates select="maxFileSize" mode="loadCapDetail"/>
    <xsl:apply-templates select="testQuery/pos/long" mode="loadTQDetail">
      <xsl:with-param name="subtype">pos.long</xsl:with-param>
    </xsl:apply-templates>
    <xsl:apply-templates select="testQuery/pos/lat" mode="loadTQDetail">
      <xsl:with-param name="subtype">pos.lat</xsl:with-param>
    </xsl:apply-templates>
    <xsl:apply-templates select="testQuery/pos/refframe" mode="loadTQDetail">
      <xsl:with-param name="subtype">pos.refframe</xsl:with-param>
    </xsl:apply-templates>
    <xsl:apply-templates select="testQuery/size" mode="loadTQDetail"/>
    <xsl:apply-templates select="testQuery/queryDataCmd" mode="loadTQDetail"/>
  
    <xsl:apply-templates select="interface/testQueryString" mode="loadTQSDetail"/>
  </xsl:template>

  <xsl:template match="capability" mode="type_SLAP">
    <xsl:param name="seq" select="1"/>
    <xsl:param name="base">SLAP_</xsl:param>
    <xsl:param name="name" select="concat($base,string($seq))"/>

    <xsl:apply-templates select="." mode="type_Capability">
      <xsl:with-param name="seq" select="$seq"/>
      <xsl:with-param name="name" select="$name"/>
    </xsl:apply-templates>

    <xsl:apply-templates select="complianceLevel" mode="loadCapDetail"/>
    <xsl:apply-templates select="dataSource" mode="loadCapDetail"/>
    <xsl:apply-templates select="maxRecords" mode="loadCapDetail"/>

    <xsl:apply-templates mode="loadTQDetail"
                         select="testQuery/wavelength/minWavelength">
      <xsl:with-param
           name="subtype">wavelength.minWavelength</xsl:with-param>
    </xsl:apply-templates>
    <xsl:apply-templates mode="loadTQDetail"
                         select="testQuery/wavelength/maxWavelength">
      <xsl:with-param
           name="subtype">wavelength.maxWavelength</xsl:with-param>
    </xsl:apply-templates>

    <xsl:apply-templates select="testQuery/queryDataCmd" mode="loadTQDetail"/>
    <xsl:apply-templates select="interface/testQueryString" mode="loadTQSDetail"/>

  </xsl:template>

  <xsl:template match="capability" mode="type_TAP">
    <xsl:param name="seq" select="1"/>
    <xsl:param name="name" select="concat('TAP_',string($seq))"/>

    <xsl:apply-templates select="." mode="type_Capability">
      <xsl:with-param name="seq" select="$seq"/>
      <xsl:with-param name="name" select="$name"/>
    </xsl:apply-templates>

    <xsl:apply-templates select="dataModel" mode="loadCapDetail"/>
    <xsl:apply-templates select="dataModel/@ivo-id" mode="loadCapDetail">
      <xsl:with-param name="subtype">dataModel.ivoid</xsl:with-param>
      <xsl:with-param name="attributePath" select="'/capability/dataModel/@ivo-id'"/>  
    </xsl:apply-templates>
    <xsl:apply-templates select="language/name" mode="loadCapDetail">
      <xsl:with-param name="subtype">language.name</xsl:with-param>
    </xsl:apply-templates>
    <xsl:apply-templates select="language/version/@ivo-id" mode="loadCapDetail">
        <xsl:with-param name="attributePath" select="'/capability/language/version/@ivo-id'"/>  
    </xsl:apply-templates>

    <xsl:apply-templates select="uploadMethod/@ivo-id" mode="loadCapDetail">
      <xsl:with-param name="subtype">uploadMethod.ivoid</xsl:with-param>
    </xsl:apply-templates>
    <xsl:apply-templates select="outputFormat/mime" mode="loadCapDetail">
      <xsl:with-param name="subtype">outputFormat.mime</xsl:with-param>
    </xsl:apply-templates>
    <xsl:apply-templates select="outputFormat/@ivo-id" mode="loadCapDetail">
      <xsl:with-param name="subtype">outputFormat.ivoid</xsl:with-param>
      <xsl:with-param name="attributePath" select="'/capability/outputFormat/@ivo-id'"/>  
    </xsl:apply-templates>
    <xsl:apply-templates select="retentionPeriod/hard" mode="loadCapDetail">
      <xsl:with-param name="subtype">retentionPeriod.hard</xsl:with-param>
    </xsl:apply-templates>
    <xsl:apply-templates select="retentionPeriod/default" mode="loadCapDetail">
      <xsl:with-param name="subtype">retentionPeriod.default</xsl:with-param>
    </xsl:apply-templates>
    <xsl:apply-templates select="executionDuration/hard" mode="loadCapDetail">
      <xsl:with-param name="subtype">executionDuration.hard</xsl:with-param>
    </xsl:apply-templates>
    <xsl:apply-templates select="executionDuration/default" mode="loadCapDetail">
      <xsl:with-param name="subtype">executionDuration.default</xsl:with-param>
    </xsl:apply-templates>
    <xsl:apply-templates select="outputLimit/hard" mode="loadCapDetail">
      <xsl:with-param name="subtype">outputLimit.hard</xsl:with-param>
    </xsl:apply-templates>
    <xsl:apply-templates select="outputLimit/default" mode="loadCapDetail">
      <xsl:with-param name="subtype">outputLimit.default</xsl:with-param>
    </xsl:apply-templates>
    <xsl:apply-templates select="uploadLimit/hard" mode="loadCapDetail">
      <xsl:with-param name="subtype">uploadLimit.hard</xsl:with-param>
    </xsl:apply-templates>
    <xsl:apply-templates select="uploadLimit/default" mode="loadCapDetail">
      <xsl:with-param name="subtype">uploadLimit.default</xsl:with-param>
    </xsl:apply-templates>

    <xsl:apply-templates select="interface/testQueryString" mode="loadTQSDetail"/>
  </xsl:template>

  <!--loading resource-level details, not in a capability-->
  <xsl:template match="*[identifier]//*|*[identifier]//@*" mode="loadResDetail">
    <xsl:param name="basetype">vor:resource.</xsl:param>
    <xsl:param name="subtype" select="local-name(.)"/>
    <xsl:param name="utype" select="concat($basetype,$subtype)"/>
    <xsl:param name="attributePath" select="'none'"/>

    <xsl:variable name="xpath">
      <xsl:choose>
        <xsl:when test="$attributePath = 'none'">
          <xsl:call-template name="mode_detailPath"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="$attributePath"/>      
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>

    <xsl:call-template name="loadDetail">
      <xsl:with-param name="incap" select="false()"/>
      <xsl:with-param name="val" select="."/>
      <xsl:with-param name="detail_xpath" select="$xpath"></xsl:with-param>
    </xsl:call-template>
  </xsl:template>

  <xsl:template match="capability//*|capability//@*" mode="loadCapDetail">
    <xsl:param name="basetype">vor:capability.</xsl:param>
    <xsl:param name="subtype" select="local-name(.)"/>
    <xsl:param name="attributePath" select="'none'"/>

    <xsl:variable name="xpath">
      <xsl:choose>
        <xsl:when test="$attributePath = 'none'">
          <xsl:call-template name="mode_detailPath"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="$attributePath"/>      
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>

    <xsl:call-template name="loadDetail">
      <xsl:with-param name="val" select="."/>
      <xsl:with-param name="detail_xpath" select="$xpath"></xsl:with-param>
    </xsl:call-template>
  </xsl:template>

  <xsl:template match="testQuery//*" mode="loadTQDetail">
    <xsl:param name="subtype" select="local-name(.)"/>

    <xsl:apply-templates select="." mode="loadCapDetail">
      <xsl:with-param name="basetype">
        <xsl:text>vor:capability.testQuery.</xsl:text>
      </xsl:with-param>
      <xsl:with-param name="subtype" select="$subtype"/>
    </xsl:apply-templates>
  </xsl:template>
  
  <xsl:template match="testQueryString" mode="loadTQSDetail">
    <xsl:apply-templates select="." mode="loadCapDetail">
      <xsl:with-param name="basetype">
        <xsl:text>vor:capability.interface.testQueryString</xsl:text>
      </xsl:with-param>
    </xsl:apply-templates>
  </xsl:template>

  <xsl:template match="maxRecords">
    <xsl:apply-templates select="." mode="loadCapDetail"/>
  </xsl:template>

  <xsl:template match="capability/maxImageSize[lat or long]">
    <!-- 1.0 version of element: convert to v1.1 mechanism -->
    <xsl:variable name="val">
      <xsl:choose>
        <xsl:when test="lat and long">
          <xsl:choose>
            <xsl:when test="number(lat) > number(long)">
              <xsl:value-of select="lat"/>
            </xsl:when>
            <xsl:otherwise>
              <xsl:value-of select="long"/>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:when>
        <xsl:when test="lat">
          <xsl:value-of select="lat"/>
        </xsl:when>
        <xsl:when test="long">
          <xsl:value-of select="long"/>
        </xsl:when>
      </xsl:choose>
    </xsl:variable>

    <xsl:call-template name="loadMaxImageSize">
      <xsl:with-param name="val" select="$val"/>
    </xsl:call-template>
  </xsl:template>

  <xsl:template match="capability/maxImageSize" priority="-1">
    <!-- v1.0 version of element -->
    <xsl:call-template name="loadMaxImageSize">
      <xsl:with-param name="val" select="."/>
    </xsl:call-template>
  </xsl:template>

  <xsl:template name="loadMaxImageSize">
    <xsl:param name="val"/>
    <xsl:call-template name="loadDetail">
      <xsl:with-param
           name="utype">vor:capability.maxImageSize</xsl:with-param>
      <xsl:with-param name="val" select="$val"/>
      <xsl:with-param name="detail_xpath">/capability/maxImageSize</xsl:with-param>
    </xsl:call-template>
  </xsl:template>

  <!-- ################################################################ 
  -  handle interfaces: determine interface type and load
  -  ################################################################ -->

  <!--
     -  handle an interface element
     -->
  <xsl:template match="interface" priority="-2">
    <xsl:param name="seq" select="1"/>
    <xsl:apply-templates select="." mode="type_Interface">
      <xsl:with-param name="seq" select="$seq"/>
    </xsl:apply-templates>
  </xsl:template>

  <xsl:template match="interface[substring-after(@xsi:type,':')='webservice']">
    <xsl:param name="seq" select="1"/>
    <xsl:apply-templates select="." mode="type_WebService">
      <xsl:with-param name="seq" select="$seq"/>
    </xsl:apply-templates>
  </xsl:template>

  <xsl:template match="interface[substring-after(@xsi:type,':')='paramhttp']">
    <xsl:param name="seq" select="1"/>
    <xsl:apply-templates select="." mode="type_ParamHTTP">
      <xsl:with-param name="seq" select="$seq"/>
    </xsl:apply-templates>
  </xsl:template>

  <!-- ################################################################ 
  -  handle specific interface types
  -  ################################################################ -->

  <xsl:template match="interface" mode="type_Interface">
    <xsl:param name="seq" select="1"/>
    <xsl:param name="urluse">full</xsl:param>

    <xsl:text>SET @rrifseq = </xsl:text>
    <xsl:value-of select="$seq"/>
    <xsl:text>;
</xsl:text>
    <xsl:apply-templates select="." mode="table_interface">
      <xsl:with-param name="urluse" select="$urluse"/>
    </xsl:apply-templates>
  </xsl:template>

  <xsl:template match="interface" mode="type_WebService">
    <xsl:param name="seq" select="1"/>

    <xsl:variable name="urluse">
      <xsl:choose>
        <xsl:when test="accessURL[1]/@use">
          <xsl:value-of select="accessURL[1]/@use"/>
        </xsl:when>
        <xsl:otherwise>post</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>

    <xsl:apply-templates select="." mode="type_Interface">
      <xsl:with-param name="seq" select="$seq"/>
      <xsl:with-param name="urluse" select="$urluse"/>
    </xsl:apply-templates>

    <xsl:if test="wsdlURL">
      <xsl:text>
-- add extras for WebService (SOAP) interface
</xsl:text>

      <xsl:text>UPDATE </xsl:text>
      <xsl:value-of select="$rr"/>
      <xsl:text>.interface SET
        wsdl_url=</xsl:text>
      <xsl:call-template name="mkstrval">
        <xsl:with-param name="valnodes" select="wsdlURL[1]"/>
      </xsl:call-template>
      <xsl:text>
    WHERE (ivoid=@rrivoid and cap_index=@rrcapseq and intf_index=@rrifseq);
</xsl:text>
    </xsl:if>

  </xsl:template>

  <!--
     -  handle a ParamHTTP interface
     -->
  <xsl:template match="interface" mode="type_ParamHTTP">
    <xsl:param name="seq" select="1"/>

    <xsl:variable name="urluse">
      <xsl:choose>
        <xsl:when test="accessURL[1]/@use">
          <xsl:value-of select="accessURL[1]/@use"/>
        </xsl:when>
        <xsl:otherwise>base</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>

    <xsl:apply-templates select="." mode="type_Interface">
      <xsl:with-param name="seq" select="$seq"/>
      <xsl:with-param name="urluse" select="$urluse"/>
    </xsl:apply-templates>


    <!-- add parameter descriptions -->
    <xsl:apply-templates select="param" mode="table_param"/>

    <xsl:call-template name="loadDetail">
      <xsl:with-param
           name="utype">vor:capability.paramHTTP.testQuery</xsl:with-param>
      <xsl:with-param name="val" select="testQuery"/>
      <xsl:with-param name="detail_xpath">/capability/testQuery</xsl:with-param>
    </xsl:call-template>
  </xsl:template>

  <!-- ################################################################ 
  -  handle tableset structures
  -  ################################################################ -->

  <!--
     -  handle a tableset element
     -->
  <xsl:template match="tableset">
    <xsl:text>-- load tableset information
</xsl:text>
    <xsl:for-each select="schema">
      <xsl:apply-templates select=".">
        <xsl:with-param name="seq" select="position()"/>
      </xsl:apply-templates>
    </xsl:for-each>
  </xsl:template>

  <!--
     -  handle a schema element
     -->
  <xsl:template match="schema">
    <xsl:param name="seq" select="1"/>

    <xsl:text>SET @rrschemaseq = </xsl:text>
    <xsl:value-of select="$seq"/>
    <xsl:text>;
</xsl:text>

    <!-- load schema table -->
    <xsl:apply-templates select="." mode="table_schema">
      <xsl:with-param name="seq" select="$seq"/>
    </xsl:apply-templates>

    <!-- load each table within the schema -->
    <xsl:for-each select="table">
      <xsl:apply-templates select=".">
        <xsl:with-param name="seq" select="position()"/>
      </xsl:apply-templates>
    </xsl:for-each>
  </xsl:template>

  <!--
     -  handle a VODataService 1.0 catalog element
     -->
  <xsl:template match="*[table]" mode="vods10">
    <xsl:param name="seq" select="1"/>
    <xsl:param name="name">
      <xsl:value-of select="$seq"/>
    </xsl:param>
    <xsl:param name="title">
      <xsl:text>Catalog: </xsl:text>
      <xsl:value-of select="/*/title"/>
      <xsl:if test="count(../catalog) &gt; 1">
        <xsl:text> (</xsl:text>
        <xsl:value-of select="$seq"/>
        <xsl:text>)</xsl:text>
      </xsl:if>
    </xsl:param>
    <xsl:param name="desc">
      <xsl:text>This is the catalog that corresponds to the </xsl:text>
      <xsl:value-of select="normalize-space(/*/title)"/>
      <xsl:text>.</xsl:text>
    </xsl:param>

    <xsl:text>SET @rrschemaseq = </xsl:text>
    <xsl:value-of select="$seq"/>
    <xsl:text>;
</xsl:text>

    <!-- load schema table -->
    <xsl:text>INSERT INTO </xsl:text>
    <xsl:value-of select="$rr"/>
    <xsl:text>.res_schema (
      ivoid, schema_index, schema_name,
      schema_title,
      schema_description
    ) VALUES (
      @rrivoid, </xsl:text>
    <xsl:value-of select="$seq"/>
    <xsl:text>, </xsl:text>
    <xsl:call-template name="mkstrval">
      <xsl:with-param name="valnodes" select="$name"/>
    </xsl:call-template>
    <xsl:text>, </xsl:text>
    <xsl:call-template name="mkstrval">
      <xsl:with-param name="valnodes" select="$title"/>
    </xsl:call-template>
    <xsl:text>, 
      </xsl:text>
    <xsl:call-template name="mkstrval">
      <xsl:with-param name="valnodes" select="$desc"/>
    </xsl:call-template>
    <xsl:text> 
    );
</xsl:text>

    <!-- load each table within the catalog -->
    <xsl:for-each select="table">
      <xsl:apply-templates select=".">
        <xsl:with-param name="seq" select="position()"/>
      </xsl:apply-templates>
    </xsl:for-each>

  </xsl:template>

  <!--
     -  load the metadata for a table
     -->
  <xsl:template match="table">
    <xsl:param name="seq" select="1"/>

    <xsl:text>SET @rrtableseq = </xsl:text>
    <xsl:value-of select="$seq"/>
    <xsl:text>;
</xsl:text>

    <!-- load table table -->
    <xsl:apply-templates select="." mode="table_table">
      <xsl:with-param name="seq" select="$seq"/>
    </xsl:apply-templates>

    <xsl:apply-templates select="column" mode="table_column"/>
  </xsl:template>

  <!-- ################################################################ 
  -  load specific database tables
  -  ################################################################ -->

  <!-- 
     -  load data into the resource table
     -->
  <xsl:template match="*" mode="table_resource">

    <xsl:variable name="rtype">
      <xsl:choose>
        <xsl:when test="@xsi:type">
          <xsl:value-of select="@xsi:type"/>
        </xsl:when>
        <xsl:otherwise>vr:resource</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>


    <xsl:text>INSERT INTO </xsl:text>
    <xsl:value-of select="$rr"/>
    <xsl:text>.resource (
      ivoid, res_type, 
      created, updated, short_name, 
      res_title, 
      res_description, 
      content_level, content_type, reference_url, 
      source_value, source_format, res_version 
   ) VALUES ( 
      </xsl:text>
    <xsl:call-template name="mkstrval">
      <xsl:with-param name="valnodes" select="identifier"/>
    </xsl:call-template>
    <xsl:text>, </xsl:text>
    <xsl:text>'</xsl:text>
    <xsl:value-of select="$rtype"/>
    <xsl:text>',
      </xsl:text>
    <xsl:call-template name="mktimeval">
      <xsl:with-param name="valnodes" select="@created"/>
    </xsl:call-template>
    <xsl:text>, </xsl:text>
    <xsl:call-template name="mktimeval">
      <xsl:with-param name="valnodes" select="@updated"/>
    </xsl:call-template>
    <xsl:text>, </xsl:text>
    <xsl:call-template name="mkstrval">
      <xsl:with-param name="valnodes" select="shortName"/>
    </xsl:call-template>
    <xsl:text>, 
      </xsl:text>
    <xsl:call-template name="mkstrval">
      <xsl:with-param name="valnodes" select="title"/>
      <xsl:with-param name="notnull" select="true()"/>
    </xsl:call-template>
    <xsl:text>, 
      </xsl:text>
    <xsl:call-template name="mkstrval">
      <xsl:with-param name="valnodes" select="content/description"/>
      <xsl:with-param name="notnull" select="true()"/>
    </xsl:call-template>
    <xsl:text>, 
      </xsl:text>
    <xsl:call-template name="mkstrval">
      <xsl:with-param name="valnodes" select="content/contentLevel"/>
      <xsl:with-param name="asarray" select="true()"/>
    </xsl:call-template>
    <xsl:text>, </xsl:text>
    <xsl:call-template name="mkstrval">
      <xsl:with-param name="valnodes" select="content/type"/>
      <xsl:with-param name="asarray" select="true()"/>
    </xsl:call-template>
    <xsl:text>, </xsl:text>
    <xsl:call-template name="mkstrval">
      <xsl:with-param name="valnodes" select="content/referenceURL"/>
      <xsl:with-param name="notnull" select="true()"/>
      <xsl:with-param name="asarray" select="true()"/>
    </xsl:call-template>
    <xsl:text>, 
      </xsl:text>
    <xsl:call-template name="mkstrval">
      <xsl:with-param name="valnodes" select="content/source"/>
    </xsl:call-template>
    <xsl:text>, </xsl:text>
    <xsl:call-template name="mkstrval">
      <xsl:with-param name="valnodes" select="content/source/@format"/>
    </xsl:call-template>
    <xsl:text>, </xsl:text>
    <xsl:call-template name="mkstrval">
      <xsl:with-param name="valnodes" select="curation/version"/>
    </xsl:call-template>
    <xsl:text>
   );
</xsl:text>

    <xsl:text>SET @rrivoid = </xsl:text>
    <xsl:call-template name="mkstrval">
      <xsl:with-param name="valnodes" select="identifier"/>
    </xsl:call-template>
    <xsl:text>;
</xsl:text>

  </xsl:template>

  <!--
     -  load data into the capability table
     -->
  <xsl:template match="capability" mode="table_capability">
    <xsl:param name="name"/>
    <xsl:param name="type">
      <xsl:choose>
        <xsl:when test="contains(@xsi:type,':')">
          <xsl:value-of select="substring-after(@xsi:type,':')"/>
        </xsl:when>
        <xsl:when test="@xsi:type">
          <xsl:value-of select="@xsi:type"/>
        </xsl:when>
        <xsl:otherwise>capability</xsl:otherwise>
      </xsl:choose>
    </xsl:param>

    <xsl:text>INSERT INTO </xsl:text>
    <xsl:value-of select="$rr"/>
    <xsl:text>.capability (
      ivoid, cap_index, cap_type,
      standard_id,
      cap_description
    ) VALUES (
      @rrivoid, @rrcapseq, </xsl:text>
    <xsl:call-template name="mkstrval">
      <xsl:with-param name="valnodes" select="$type"/>
    </xsl:call-template>
    <xsl:text>, </xsl:text>

    <xsl:call-template name="mkstrval">
      <xsl:with-param name="valnodes" select="@standardID"/>
    </xsl:call-template>
    <xsl:text>, 
      </xsl:text>

    <xsl:call-template name="mkstrval">
      <xsl:with-param name="valnodes" select="description"/>
    </xsl:call-template>

    <xsl:text>
    );
</xsl:text>

  </xsl:template>

  <!--
     -  load data into the interface table
     -->
  <xsl:template match="interface" mode="table_interface">
    <xsl:param name="urluse">full</xsl:param>
    <xsl:param name="type">
      <xsl:choose>
        <xsl:when test="@xsi:type">
          <xsl:value-of select="@xsi:type"/>
        </xsl:when>
        <xsl:otherwise>Interface</xsl:otherwise>
      </xsl:choose>
    </xsl:param>
    <xsl:param name="role">
      <xsl:choose>
        <xsl:when test="@role">
          <xsl:value-of select="@role"/>
        </xsl:when>
        <xsl:when test="string-length(../@standardID)!=0 and 
                            (@version or count(../interface)=1)">
          <xsl:text>std</xsl:text>
        </xsl:when>
      </xsl:choose>
    </xsl:param>

    <xsl:text>INSERT INTO </xsl:text>
    <xsl:value-of select="$rr"/>
    <xsl:text>.interface (
      ivoid, cap_index, intf_index, intf_type, intf_role, std_version,
      url_use, access_url, mirror_url
    ) VALUES (
      @rrivoid, @rrcapseq, @rrifseq, </xsl:text>
    <xsl:call-template name="mkstrval">
      <xsl:with-param name="valnodes" select="$type"/>
    </xsl:call-template>
    <xsl:text>, </xsl:text>
    <xsl:call-template name="mkstrval">
      <xsl:with-param name="valnodes" select="$role"/>
    </xsl:call-template>
    <xsl:text>, </xsl:text>
    <xsl:call-template name="mkstrval">
      <xsl:with-param name="valnodes" select="@version"/>
    </xsl:call-template>
    <xsl:text>, 
      </xsl:text>
    <xsl:call-template name="mkstrval">
      <xsl:with-param name="valnodes" select="$urluse"/>
      <xsl:with-param name="notnull" select="true()"/>
    </xsl:call-template>
    <xsl:text>, </xsl:text>
    <!--According to the resource standard there may be more than one accessURL but behavior is undefined. Use only the first.-->
    <xsl:call-template name="mkstrval">
      <xsl:with-param name="valnodes" select="accessURL[1]"/>
      <xsl:with-param name="notnull" select="true()"/>
    </xsl:call-template>
    <xsl:text>, </xsl:text>
    <xsl:call-template name="mkstrval">
      <xsl:with-param name="valnodes" select="mirrorURL"/>
      <xsl:with-param name="asarray" select="true()"/>
    </xsl:call-template>
    <xsl:text>
    );
</xsl:text>

  </xsl:template>

  <!--
     -  
     -->
  <xsl:template match="param" mode="table_param">

    <xsl:text>
-- insert the supported parameters
INSERT INTO </xsl:text>
    <xsl:value-of select="$rr"/>
    <xsl:text>.intf_param (
     ivoid, cap_index, intf_index, name, 
     datatype, arraysize, delim, unit, ucd, utype, std, extended_schema, extended_type, param_use, 
     param_description
) VALUES (
     @rrivoid,@rrcapseq,@rrifseq, </xsl:text>
    <xsl:call-template name="mkstrval">
      <xsl:with-param name="valnodes" select="name"/>
    </xsl:call-template>
    <xsl:text>,
     </xsl:text>
    <xsl:call-template name="mkstrval">
      <xsl:with-param name="valnodes" select="dataType"/>
    </xsl:call-template>
    <xsl:text>, </xsl:text>
    <xsl:call-template name="mkstrval">
      <xsl:with-param name="valnodes" select="arraysize"/>
    </xsl:call-template>
    <xsl:text>, </xsl:text>
    <xsl:call-template name="mkstrval">
      <xsl:with-param name="valnodes" select="delim"/>
    </xsl:call-template>
    <xsl:text>, </xsl:text>
    <xsl:call-template name="mkstrval">
      <xsl:with-param name="valnodes" select="unit"/>
    </xsl:call-template>
    <xsl:text>, </xsl:text>
    <xsl:call-template name="mkstrval">
      <xsl:with-param name="valnodes" select="ucd"/>
    </xsl:call-template>
    <xsl:text>, </xsl:text>
    <xsl:call-template name="mkstrval">
      <xsl:with-param name="valnodes" select="utype"/>
    </xsl:call-template>
    <xsl:text>, </xsl:text>
    <xsl:choose>
      <xsl:when test="@std='false' or @std='0'">0</xsl:when>
      <xsl:when test="@std">1</xsl:when>
      <xsl:when test="../@standardID">1</xsl:when>
      <xsl:otherwise>0</xsl:otherwise>
    </xsl:choose>
    <xsl:text>, 
     </xsl:text>
    <xsl:call-template name="mkstrval">
      <xsl:with-param name="valnodes" select="dataType/@extendedType"/>
    </xsl:call-template>
    <xsl:text>, </xsl:text>
    <xsl:call-template name="mkstrval">
      <xsl:with-param name="valnodes" select="dataType/@extendedType"/>
    </xsl:call-template>
    <xsl:text>, </xsl:text>
    <xsl:call-template name="mkstrval">
      <xsl:with-param name="valnodes" select="@use"/>
    </xsl:call-template>
    <xsl:text>,
     </xsl:text>
    <xsl:call-template name="mkstrval">
      <xsl:with-param name="valnodes" select="description"/>
    </xsl:call-template>
    <xsl:text>
);
</xsl:text>
  </xsl:template>

  <!--
     -  load data into the schema table
     -->
  <xsl:template match="schema" mode="table_schema">
    <xsl:param name="seq" select="1"/>

    <xsl:text>INSERT INTO </xsl:text>
    <xsl:value-of select="$rr"/>
    <xsl:text>.res_schema (
      ivoid, schema_index, schema_name, schema_utype,
      schema_title,
      schema_description
    ) VALUES (
     @rrivoid, </xsl:text>
    <xsl:value-of select="$seq"/>
    <xsl:text>, </xsl:text>
    <xsl:call-template name="mkstrval">
      <xsl:with-param name="valnodes" select="name"/>
    </xsl:call-template>
    <xsl:text>, </xsl:text>
    <xsl:call-template name="mkstrval">
      <xsl:with-param name="valnodes" select="utype"/>
    </xsl:call-template>
    <xsl:text>, 
      </xsl:text>
    <xsl:call-template name="mkstrval">
      <xsl:with-param name="valnodes" select="title"/>
    </xsl:call-template>
    <xsl:text>, 
      </xsl:text>
    <xsl:call-template name="mkstrval">
      <xsl:with-param name="valnodes" select="description"/>
    </xsl:call-template>
    <xsl:text> 
    );
</xsl:text>

  </xsl:template>

  <!--
     -  load data into the table table 
     -->
  <xsl:template match="table" mode="table_table">
    <xsl:param name="seq" select="1"/>

    <xsl:text>INSERT INTO </xsl:text>
    <xsl:value-of select="$rr"/>
    <xsl:text>.res_table (
      ivoid, schema_index, table_index, 
      table_name, table_type, table_utype, 
      table_title,
      table_description
    ) VALUES (
      @rrivoid, @rrschemaseq, </xsl:text>
    <xsl:value-of select="$seq"/>
    <xsl:text>, 
      </xsl:text>
    <xsl:call-template name="mkstrval">
      <xsl:with-param name="valnodes" select="name"/>
    </xsl:call-template>
    <xsl:text>, </xsl:text>
    <xsl:call-template name="mkstrval">
      <xsl:with-param name="valnodes" select="@type"/>
    </xsl:call-template>
    <xsl:text>, </xsl:text>
    <xsl:call-template name="mkstrval">
      <xsl:with-param name="valnodes" select="utype"/>
    </xsl:call-template>
    <xsl:text>, 
      </xsl:text>
    <xsl:call-template name="mkstrval">
      <xsl:with-param name="valnodes" select="title"/>
    </xsl:call-template>
    <xsl:text>, 
      </xsl:text>
    <xsl:call-template name="mkstrval">
      <xsl:with-param name="valnodes" select="description"/>
    </xsl:call-template>
    <xsl:text> 
    );
</xsl:text>
  </xsl:template>

  <!--
     -  load data into the column table
     -->
  <xsl:template match="column" mode="table_column">
    <xsl:text>INSERT INTO </xsl:text>
    <xsl:value-of select="$rr"/>
    <xsl:text>.table_column (
      ivoid, table_index, name, 
      datatype, arraysize, delim, unit, ucd, utype, flag, std, 
      extended_schema, extended_type, type_system,
      column_description
    ) VALUES (
      @rrivoid, @rrtableseq, </xsl:text>
    <xsl:call-template name="mkstrval">
      <xsl:with-param name="valnodes" select="name"/>
    </xsl:call-template>
    <xsl:text>,
     </xsl:text>
    <xsl:call-template name="mkstrval">
      <xsl:with-param name="valnodes" select="dataType"/>
    </xsl:call-template>
    <xsl:text>, </xsl:text>
    <xsl:call-template name="mkstrval">
      <xsl:with-param name="valnodes" select="arraysize"/>
    </xsl:call-template>
    <xsl:text>, </xsl:text>
    <xsl:call-template name="mkstrval">
      <xsl:with-param name="valnodes" select="delim"/>
    </xsl:call-template>
    <xsl:text>, </xsl:text>
    <xsl:call-template name="mkstrval">
      <xsl:with-param name="valnodes" select="unit"/>
    </xsl:call-template>
    <xsl:text>, </xsl:text>
    <xsl:call-template name="mkstrval">
      <xsl:with-param name="valnodes" select="ucd"/>
    </xsl:call-template>
    <xsl:text>, </xsl:text>
    <xsl:call-template name="mkstrval">
      <xsl:with-param name="valnodes" select="utype"/>
    </xsl:call-template>
    <xsl:text>, </xsl:text>
    <xsl:call-template name="mkstrval">
      <xsl:with-param name="valnodes" select="flag"/>
      <xsl:with-param name="asarray" select="true()"/>
    </xsl:call-template>
    <xsl:text>, </xsl:text>
    <xsl:choose>
      <xsl:when test="@std='false' or @std='0'">0</xsl:when>
      <xsl:when test="@std">1</xsl:when>
      <xsl:otherwise>NULL</xsl:otherwise>
    </xsl:choose>
    <xsl:text>, 
     </xsl:text>
    <xsl:call-template name="mkstrval">
      <xsl:with-param name="valnodes" select="dataType/@extendedType"/>
    </xsl:call-template>
    <xsl:text>, </xsl:text>
    <xsl:call-template name="mkstrval">
      <xsl:with-param name="valnodes" select="dataType/@extendedType"/>
    </xsl:call-template>
    <xsl:text>, </xsl:text>
    <xsl:call-template name="mkstrval">
      <xsl:with-param name="valnodes" select="dataType/@xsi:type"/>
    </xsl:call-template>
    <xsl:text>, 
     </xsl:text>
    <xsl:call-template name="mkstrval">
      <xsl:with-param name="valnodes" select="description"/>
    </xsl:call-template>
    <xsl:text> 
    );

</xsl:text>
  </xsl:template>

  <!--
     -  load a record into the details table
     -->
  <xsl:template name="loadDetail">
    <xsl:param name="incap" select="true()"/>
    <xsl:param name="val"/>
    <xsl:param name="detail_xpath"/>

    <xsl:variable name="cseq">
      <xsl:choose>
        <xsl:when test="$incap">@rrcapseq</xsl:when>
        <xsl:otherwise>NULL</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>

    <xsl:if test="normalize-space($val) != ''">

      <xsl:text>INSERT INTO </xsl:text>
      <xsl:value-of select="$rr"/>
      <xsl:text>.res_detail (
        ivoid, cap_index, 
        detail_value,
        detail_xpath
      ) VALUES (
        @rrivoid, </xsl:text>

      <xsl:value-of select="$cseq"/>
      <xsl:text>, 
        </xsl:text>
      <xsl:call-template name="mkstrval">
        <xsl:with-param name="valnodes" select="$val"/>
      </xsl:call-template>
      <xsl:text>, 
        </xsl:text>
      <xsl:call-template name="mkstrval">
        <xsl:with-param name="valnodes" select="$detail_xpath"/>
      </xsl:call-template>
      <xsl:text>
      );
</xsl:text>
    </xsl:if>
  </xsl:template>

  <!--
     -  load data into the validation table
     -->
  <xsl:template match="validationLevel">
    <xsl:param name="iscap" select="boolean(parent::capability)"/>

    <xsl:param name="validatedby">
      <xsl:choose>
        <xsl:when test="@validatedBy">
          <xsl:value-of select="@validatedBy"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="$harvestedFromID"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:param>

    <xsl:text>INSERT INTO </xsl:text>
    <xsl:value-of select="$rr"/>
    <xsl:text>.validation (
      ivoid, validated_by, val_level</xsl:text>

    <xsl:if test="$iscap">
      <xsl:text>,
      cap_index</xsl:text>
    </xsl:if>

    <xsl:text>
    ) VALUES (
      @rrivoid, </xsl:text>

    <xsl:call-template name="mkstrval">
      <xsl:with-param name="valnodes" select="$validatedby"/>
    </xsl:call-template>
    <xsl:text>, </xsl:text>
    <xsl:value-of select="."/>

    <xsl:if test="$iscap">
      <xsl:text>,
      @rrcapseq</xsl:text>
    </xsl:if>

    <xsl:text>
    );
</xsl:text>
  </xsl:template>

   <!-- ################################################################ 
  -  utility and data extraction templates
  -  ################################################################ -->

   <!--
     -  extract an "attribute" value from a processing instruction
     -->
  <xsl:template match="processing-instruction()" mode="harvestinfo">
    <xsl:param name="attr"/>
    <xsl:call-template name="parseProcInstNV">
      <xsl:with-param name="attr" select="$attr"/>
      <xsl:with-param name="val" select="string(.)"/>
    </xsl:call-template>
  </xsl:template>

  <xsl:template name="parseProcInstNV">
    <xsl:param name="attr"/>
    <xsl:param name="val"/>

    <xsl:variable name="attreq" select="concat($attr,'=')"/>
    <xsl:variable name="qvalplus" select="substring-after($val,$attreq)"/>
    <xsl:variable name="q" select="substring($qvalplus,1,1)"/>

    <xsl:if test="$qvalplus">
      <xsl:value-of select="substring-before(substring($qvalplus,2),$q)"/>
    </xsl:if>
  </xsl:template>

  <!--
     -  create a timestamp value 
     -->
  <xsl:template name="mktimeval">
    <xsl:param name="valnodes"/>

    <xsl:call-template name="mkstrval">
      <xsl:with-param name="valnodes" select="$valnodes"/>
    </xsl:call-template>
  </xsl:template>

  <!--
     -  create a date value 
     -->
  <xsl:template name="mkdateval">
    <xsl:param name="valnodes"/>

    <xsl:call-template name="mkstrval">
      <xsl:with-param name="valnodes" select="$valnodes"/>
    </xsl:call-template>
  </xsl:template>
  
  <!--
     -  create / convert date roles to RegTAP 1.1 vocabulary
     -->
  <xsl:template name="convertdaterole">
    <xsl:param name="valnodes"/>
    
    <xsl:choose>
      <xsl:when test="string-length(string($valnodes))=0">
        <xsl:text>NULL</xsl:text>
      </xsl:when>
      <xsl:when test="normalize-space($valnodes) = 'representative'">
          <xsl:text>'Collected'</xsl:text>
      </xsl:when>
      <xsl:when test="normalize-space($valnodes) = 'creation'">
          <xsl:text>'Created'</xsl:text>
      </xsl:when>
     <xsl:when test="normalize-space($valnodes) = 'update'">
          <xsl:text>'Updated'</xsl:text>
      </xsl:when>     
      <xsl:otherwise>
        <xsl:text>'</xsl:text>
        <xsl:call-template name="sanitize">
          <xsl:with-param select="normalize-space($valnodes)" name="text"/>
        </xsl:call-template>
        <xsl:text>'</xsl:text>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
    <!--
     -  create / convert relationship types to RegTAP 1.1 vocabulary
     -->
  <xsl:template name="convertrelationshiptype">
    <xsl:param name="valnodes" select="'related-to'"/>
    <xsl:choose>
      <xsl:when test="normalize-space($valnodes) = 'mirror-of'">
          <xsl:text>'IsIdenticalTo'</xsl:text>
      </xsl:when>
      <xsl:when test="normalize-space($valnodes) = 'service-for'">
          <xsl:text>'IsServiceFor'</xsl:text>
      </xsl:when>
     <xsl:when test="normalize-space($valnodes) = 'served-by'">
          <xsl:text>'IsServedBy'</xsl:text>
      </xsl:when>   
      <xsl:when test="normalize-space($valnodes) = 'derived-from'">
          <xsl:text>'IsDerivedFrom'</xsl:text>
      </xsl:when>   
      <xsl:otherwise>
        <xsl:text>'</xsl:text>
        <xsl:call-template name="sanitize">
          <xsl:with-param select="normalize-space($valnodes)" name="text"/>
        </xsl:call-template>
        <xsl:text>'</xsl:text>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>


  <!--
     -  create a string value 
     -->
  <xsl:template name="mkstrval">
    <xsl:param name="valnodes"/>
    <xsl:param select="false()" name="asarray"/>
    <xsl:param name="notnull" select="false()"/>

    <xsl:choose>
      <xsl:when test="not($notnull) and string-length(string($valnodes))=0">
        <xsl:text>NULL</xsl:text>
      </xsl:when>
      <xsl:when test="$asarray">
        <xsl:text>'</xsl:text>
        <xsl:for-each select="$valnodes">
          <xsl:if test="position()>1">
            <xsl:text>#</xsl:text>
          </xsl:if>
          <xsl:call-template name="sanitize">
            <xsl:with-param select="normalize-space(.)" name="text"/>
          </xsl:call-template>
        </xsl:for-each>
        <xsl:text>'</xsl:text>
      </xsl:when>
      <xsl:otherwise>
        <xsl:text>'</xsl:text>
        <xsl:call-template name="sanitize">
          <xsl:with-param select="normalize-space($valnodes)" name="text"/>
        </xsl:call-template>
        <xsl:text>'</xsl:text>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!--
     -  sanitize a string value: this includes escaping
     -  dangerous/problematic characters as needed
     -->
  <xsl:template name="sanitize">
    <xsl:param name="text"/>
    <xsl:param name="quote">'</xsl:param>

    <xsl:call-template name="escapeQuotes">
      <xsl:with-param name="quote" select="$quote"/>
      <xsl:with-param name="text">
        <xsl:call-template name="filterProblemText">
          <xsl:with-param name="text" select="$text"/>
        </xsl:call-template>
      </xsl:with-param>
    </xsl:call-template>
  </xsl:template>


  <xsl:template name="mode_detailPath">
    <xsl:for-each select="ancestor-or-self::*">
      <!--start at level below resource-->
      <xsl:if test="not(contains(name(), 'Resource'))">
        <xsl:value-of select="concat('/',name())"/>
      </xsl:if>
    </xsl:for-each>
  </xsl:template>
  
  <!--
     -  escape any single quotes found in a string value
     -->
  <xsl:template name="escapeQuotes">
    <xsl:param name="text"/>
    <xsl:param name="quote">'</xsl:param>

    <xsl:choose>
      <xsl:when test="contains($text,$quote)">
        <xsl:value-of select="substring-before($text,$quote)"/>
        <xsl:value-of select="$quote"/>
        <xsl:value-of select="$quote"/>
        <xsl:call-template name="escapeQuotes">
          <xsl:with-param select="substring-after($text,$quote)" name="text"/>
          <xsl:with-param select="$quote" name="quote"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="$text"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!--
     -  filter out problematic character strings.  At the moment, this 
     -  takes out "\'" and "\`" (mostly from CDS records).
     -->
  <xsl:template name="filterProblemText">
    <xsl:param name="text"/>

    <xsl:call-template name="filterOutText">
      <xsl:with-param name="cseq">\'</xsl:with-param>
      <xsl:with-param name="text">
        <xsl:call-template name="filterOutText">
          <xsl:with-param name="cseq">\`</xsl:with-param>
          <xsl:with-param name="text" select="$text"/>
        </xsl:call-template>
      </xsl:with-param>
    </xsl:call-template>
  </xsl:template>

  <xsl:template name="filterOutText">
    <xsl:param name="text"/>
    <xsl:param name="cseq"/>

    <xsl:choose>
      <xsl:when test="$cseq!='' and contains($text, $cseq)">
        <xsl:value-of select="substring-before($text,$cseq)"/>
        <xsl:call-template name="filterOutText">
          <xsl:with-param name="text"
                          select="substring-after($text,$cseq)"/>
          <xsl:with-param name="cseq" select="$cseq"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="$text"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

</xsl:stylesheet>
