options(scipen = 999)
options(fftempdir = "D:/Users/ALondhe2/fftemp")

connectionDetails <- DatabaseConnector::createConnectionDetails(dbms = Sys.getenv("cdmDbms"), 
                                                                server = Sys.getenv("cdmServer"),
                                                                port = Sys.getenv("cdmServerPort"))

repoConnectionDetails <- DatabaseConnector::createConnectionDetails(dbms = Sys.getenv("repoDbms"), 
                                                                    server = Sys.getenv("repoServer"),
                                                                    port = Sys.getenv("repoServerPort"),
                                                                    user = Sys.getenv("repoUser"),
                                                                    password = Sys.getenv("repoPassword"))



comparisons <- list(
  buildComparison(targetId = 4622, comparatorId = 4516, comparisonName = "Hepatitis B"),
  buildComparison(targetId = 4514, comparatorId = 4620, comparisonName = "Hepatitis B"),
  buildComparison(targetId = 4427, comparatorId = 4615, comparisonName = "Aged 50 Patients"),
  buildComparison(targetId = 4614, comparatorId = 4616, comparisonName = "Aged 50 Patients"),
  buildComparison(targetId = 4414, comparatorId = 4425, comparisonName = "Crohn's Disease"),
  buildComparison(targetId = 4416, comparatorId = 4609, comparisonName = "Crohn's Disease"),
  buildComparison(targetId = 4512, comparatorId = 4511, comparisonName = "All Statins"),
  buildComparison(targetId = 4554, comparatorId = 4555, comparisonName = "All Statins")
)
  
cdmDatabaseSchema <- Sys.getenv("cdmDatabaseSchema")
scratchDatabaseSchema <- Sys.getenv("scratchDatabaseSchema")
ohdsiRepositorySchema <- Sys.getenv("ohdsiRepositorySchema")
tablePrefix <- Sys.getenv("tablePrefix")
webApiPrefix <- Sys.getenv("webApiPrefix")

# generateSqlCovariates(connectionDetails = connectionDetails,
#                       repoConnectionDetails = repoConnectionDetails,
#                       ohdsiRepositorySchema = ohdsiRepositorySchema,
#                       cdmDatabaseSchema = cdmDatabaseSchema,
#                       scratchDatabaseSchema = scratchDatabaseSchema,
#                       tablePrefix = tablePrefix,
#                       webApiPrefix = webApiPrefix,
#                       cdmVersion = '5.0.1',
#                       comparisons = comparisons)



for (comparison in comparisons)
{
  plotlyXy(data = getFeatures(targetId = comparison$targetId, comparatorId = comparison$comparatorId), 
           targetId = comparison$targetId, comparatorId = comparison$comparatorId, cdmDbName = Sys.getenv("CdmDbKey"), 
           title = paste(comparison$comparisonName, paste0("(", Sys.getenv("CdmDbName"), ")"), sep = " "))
}
  
