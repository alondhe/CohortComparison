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
ohdsiRepositorySchema <- "ohdsi_repository.dbo"


comparisons <- list(
  buildComparison(targetId = 4505, comparatorId = 4504),
  buildComparison(targetId = 4506, comparatorId = 4504),
  buildComparison(targetId = 4506, comparatorId = 4505)
)
cdmDatabaseSchema <- Sys.getenv("cdmDatabaseSchema")
scratchDatabaseSchema <- Sys.getenv("scratchDatabaseSchema")
tablePrefix <- Sys.getenv("tablePrefix")
webApiPrefix <- Sys.getenv("webApiPrefix")
webApiUseSsl <- as.boolean(Sys.getenv("webApiUseSsl"))[1]

generateSqlCovariates(connectionDetails = connectionDetails,  
                      repoConnectionDetails = repoConnectionDetails, 
                      ohdsiRepositorySchema = ohdsiRepositorySchema,
                      cdmDatabaseSchema = cdmDatabaseSchema, 
                      scratchDatabaseSchema = scratchDatabaseSchema, 
                      tablePrefix = tablePrefix, 
                      webApiPrefix = webApiPrefix, 
                      useHttps = webApiUseSsl, 
                      cdmVersion = '5.0.1', 
                      comparisons = comparisons)
  
