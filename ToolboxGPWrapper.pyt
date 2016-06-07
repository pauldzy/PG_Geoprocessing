import arcpy
import __builtin__

class Toolbox(object):

   def __init__(self):
      """Define the toolbox (the name of the toolbox is the name of the
      .pyt file).""";
      self.label = "ToolboxGPWrapper";
      self.alias = "";

      # List of tool classes associated with this toolbox
      self.tools = [
          ToolboxGPWrapper
      ];
      
class ToolboxGPWrapper(object):
   
   def __init__(self):
      """Define the tool (tool name is the name of the class)."""
      self.label = "ToolboxGPWrapper"
      self.name  = "ToolboxGPWrapper"
      self.description = "";
      self.canRunInBackground = False;

   def getParameterInfo(self):
      """Define parameter definitions"""
       
      # First parameter
      param0 = arcpy.Parameter(
          displayName="Geometry:"
         ,name="pGeometry"
         ,datatype="String"
         ,parameterType="Required"
         ,direction="Input"
         ,enabled=True
      );
     
      param1 = arcpy.Parameter(
          displayName="Geometry CS:"
         ,name="pGeometryCS"
         ,datatype="String"
         ,parameterType="Optional"
         ,direction="Input"
         ,enabled=True
      );
      
      param2 = arcpy.Parameter(
          displayName="Output"
         ,name="pOutput"
         ,datatype="String"
         ,parameterType="Derived"
         ,direction="Output"
      );
      
      params = [
          param0
         ,param1
         ,param2
      ];
      
      return params;

   def isLicensed(self):
      """Set whether tool is licensed to execute."""
      
      return True

   def updateParameters(self, parameters):
      """Modify the values and properties of parameters before internal
      validation is performed.  This method is called whenever a parameter
      has been changed."""
      
      return True;

   def updateMessages(self, parameters):
      """Modify the messages created by internal validation for each tool
      parameter.  This method is called after internal validation."""
      
      if not hasattr(__builtin__, "dz_deployer")  \
      or __builtin__.dz_deployer is False:
         return;
         
      return;

   def execute(self, parameters, messages):
      """The source code of the tool."""
      
      wgs84 = arcpy.SpatialReference(4326);
      
      #------------------------------------------------------------------------
      #-- Step 10
      #-- Load the simple form variables
      #------------------------------------------------------------------------
      str_geom_txt      = parameters[0].valueAsText;
      str_geom_cs       = parameters[1].valueAsText;
      
      #------------------------------------------------------------------------
      #-- Step 20
      #-- Account for silly deployer issues with AGS
      #------------------------------------------------------------------------
      if hasattr(__builtin__, "dz_deployer") \
      and __builtin__.dz_deployer is True:
         str_geom_txt = "POLYGON((-71.1776585052917 42.3902909739571,-71.1776820268866 42.3903701743239,-71.1776063012595 42.3903825660754,-71.1775826583081 42.3903033653531,-71.1776585052917 42.3902909739571))";
         str_geom_cs  = "4326";
      
      #------------------------------------------------------------------------
      #-- Step 30
      #-- Define any workspace parameters
      #-- Note that you may force the workspace to a hard-coded 
      #-- location if desired (this does not bother the AGS deployment)
      #------------------------------------------------------------------------
      arcpy.AddMessage("   Verifying SDE Environment");
      try:
         #arcpy.env.workspace = "C:\esri_dump";
         #arcpy.env.scratchWorkspace = "C:\esri_dump";
         arcpy.env.overwriteOutput = True;

      except Exception as err:
         arcpy.AddError(err);
         
      #------------------------------------------------------------------------
      #-- Step 40
      #-- Parse the geometry
      #------------------------------------------------------------------------
      arcpy.AddMessage("   Parsing geometry...");    
      (
          num_return_code
         ,str_status_message
         ,obj_geom
         ,obj_geom_cs
      ) = ToolboxGPWrapper.dz_parse_geometry_text(
          str_geom_txt
         ,str_geom_cs
      );
         
      if num_return_code != 0:
         arcpy.AddError("Geometry Error: " + str(num_return_code));
         arcpy.AddError(str_status_message);
         raise arcpy.ExecuteError;
         
      if obj_geom_cs.factoryCode != 4326:
         obj_geom = obj_geom.projectAs(
            wgs84
         );
      
      obj_geom_area_sqkm   = obj_geom.getArea("GEODESIC","SQUAREKILOMETERS");
      obj_geom_area_sqmile = obj_geom_area_sqkm * 0.386102;
      
      if obj_geom_area_sqkm < 0:
         arcpy.AddError("Negative area indicates backwards polygon, please correct.");
         raise arcpy.ExecuteError;
         
      #------------------------------------------------------------------------
      #-- Step 50
      #-- Create the database connection
      #------------------------------------------------------------------------
      try:
         sde_conn = arcpy.ArcSDESQLExecute("Database Connections\\PG_Connection.sde");
      
      except Exception as err:
         arcpy.AddError(err);
         
      #------------------------------------------------------------------------
      #-- Step 60
      #-- Build the SQL statement
      #------------------------------------------------------------------------
      sql_statement = """
         SELECT (dz.PGFunctionGP(
            ST_GeomFromText('""" + obj_geom.WKT + """',4326)
         )).*

      """;
      #arcpy.AddMessage(sql_statement);
      
      #------------------------------------------------------------------------
      #-- Step 70
      #-- Execute the SQL statement
      #------------------------------------------------------------------------
      arcpy.AddMessage("   Executing the Service");
      try:
         sde_return = sde_conn.execute(sql_statement)
      
      except Exception as err:
         arcpy.AddError(err)
         exit -1;
         
      #------------------------------------------------------------------------
      #-- Step 80
      #-- Get the results
      #------------------------------------------------------------------------                
      num_return_code    = sde_return[0][0];
      str_status_message = sde_return[0][1];
      str_output         = sde_return[0][2];
      
      #------------------------------------------------------------------------
      #-- Step 90
      #-- Combine all results
      #------------------------------------------------------------------------
      if num_return_code == 0:
      
         final_results = """{
             "num_return_code": """ + num_return_code + """ 
            ,"status_message" : \"""" + str_status_message + """\"
            ,"results" :  """ + str_output + """
         }""";
      
      else:
         final_results = """{
             "num_return_code" : """ + num_return_code + """
            ,"status_message" : \"""" + str_status_message + """\"
         }""";
         
      #------------------------------------------------------------------------
      #-- Step 100
      #-- Cough out results 
      #------------------------------------------------------------------------
      arcpy.SetParameterAsText(2,final_results);

      arcpy.AddMessage("   Processing Complete");
      
   #---------------------------------------------------------------------------
   @staticmethod
   def dz_safe_to_number(str_input):
   
      if str_input is None:
         return None;
         
      try:
         num_input = int(str_input);
         
      except ValueError:
         try:
            num_input = float(str_input);

         except ValueError:
            return None;
            
      return num_input;
      
   #---------------------------------------------------------------------------
   @staticmethod
   def dz_get_cs(str_input):
      
      num_return_code = 0;
      str_status_message = None;
      
      if str_input is None:
         return (0,None,None);
         
      num_input = ToolboxGPWrapper.dz_safe_to_number(str_input);
      
      if num_input is not None:
         try:
            sr = arcpy.SpatialReference(num_input); 
            
         except:
            num_return_code = 99;
            str_status_message = "Unable to parse input as CS";
      
      else:
         try:
            sr = arcpy.SpatialReference(str_input);
            
         except:
            try:
               sr = arcpy.SpatialReference();
               sr.loadFromString(str_input);
            
            except:
               num_return_code = 99;
               str_status_message = "Unable to parse input as CS";
               
   
      return (num_return_code,str_status_message,sr); 
      
   #---------------------------------------------------------------------------
   @staticmethod
   def dz_parse_geometry_text(str_geom_text,str_cs_text=None):
   
      num_return_code = 0;
      str_status_message = None;
      cs = None;
      geom = None;
      
      if str_geom_text is None:
         return (0,None,None);
         
      # Parse any provided cs information
      if str_cs_text is not None:
         (num_return_code,str_status_message,cs) = ToolboxGPWrapper.dz_get_cs(str_cs_text);
         
         if num_return_code != 0:
            return (num_return_code,str_status_message,None);
      
      # Try to parse the text as wkt      
      try:
         geom = arcpy.FromWKT(str_geom_text,cs);
            
      except:
         #-- Try GeoJSON Second --
         try:
            geom = arcpy.AsShape(json.loads(str_geom_text),False);
         
         except:
            pass;
         
            #-- Try Esri JSON Third --
            try:
               geom = arcpy.AsShape(json.loads(str_geom_text),True);
               
            except:
               num_return_code = -10;
               str_status_message = "Unable to parse textual geometry as either valid WKT or JSON";
           
      if geom.spatialReference is not None:
         cs = geom.spatialReference;
         
      return (num_return_code,str_status_message,geom,cs);
      
   
