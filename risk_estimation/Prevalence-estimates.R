#########################################
# Estimating Prevalent SARS-CoV-2 cases #
#########################################

wd = "/Users/shiodakayoko/Desktop/COVID19/Nate" # <--- Change here
setwd(wd)

## Load data
incidence = read.csv("incident_cases-UPDATED.csv", header = T)

## Set up parameters
end_date = nrow(incidence)  # Number of days of epidemic 
d = 5                       # Number of days from symptom onset to testing/reporting
# rho = rep(0.1, end_date)  # Reporting rate (lower boundary) (Can be time varying, but currently it's fixed)
# alpha = 5                 # ascertainment distribution. Currently fixed, so not used. (5 days from symptom onset to reporting)

## Create a vector for the infectious period distribution (Gamma distribution)
gamma_cdf <- pgamma(1:end_date, shape=2.5, rate=0.35) 
plot(gamma_cdf, bty="l", pch=16,
     xlab="Days since symptom onset", ylab="Density",
     main="Distribution of gamma (infectious period)")
# We calculated shape and rate using data from Jung, et al medRxiv (2020) 
# https://www.medrxiv.org/content/10.1101/2020.01.29.20019547v2.full.pdf
# Mean = shape/rate = 7.1 days
# SD (sqrt(shape/rate^2)) = 4.5 days

## For each location (e.g., Washington, China, etc) ...
list_location <- names(incidence)[2:ncol(incidence)]
all_Trav  <- as.data.frame(matrix(NA, nrow=nrow(incidence), ncol=ncol(incidence)))
all_Trav2 <- as.data.frame(matrix(NA, nrow=nrow(incidence), ncol=ncol(incidence)))
names(all_Trav)  <- names(incidence)
names(all_Trav2) <- names(incidence)
all_Trav$date  <- incidence$date
all_Trav2$date <- incidence$date
for (x in 1:(ncol(incidence)-1)) {
  
  par(mfrow=c(1,2))
  
  # Select a location (e.g., China, Washington, etc.)
  location <- list_location[x]
  
  # Set a reporting rate (rho) specific for each location
  if (location %in% c("Iran","Florida","Washington","Illinois")) {
    rho <- rep(0.05, end_date)
  } else if (location %in% c("Spain","Italy","Louisiana")) {
    rho <- rep(0.092, end_date)
  } else if (location %in% c("China","Germany","California")) {
    rho <- rep(0.20, end_date)
  }
  
  # Load the reported number of cases for the selected location
  C = incidence[,x+1] 
  
  # Calculate the true number of cases, I_t
  I = rep(NA, end_date) 
  for(t in (d+1+1):end_date){
    I[t-d-1] <- C[t] / rho[t] # t-d-1, because cases become infectious ~1 day before symptom onset
  }
  
  # Calculate the number of prevalent cases, P_t 
  P = rep(NA, end_date) 
  for(t in 2:end_date){
    NotRecov <- c() # Number of people who have not yet recovered by Day t-1 (i.e., these people are still infectious on Day t)
    for (i in 1:(t-1)) {
      NotRecov[i] <- I[i]*(1-gamma_cdf[t-i])
    }
    P[t] <- sum(NotRecov) + I[t]
  }
  P[1] <- I[1] # Number of prevalent cases on Day 1 = Number of true cases on Day 1
  
  # Make a plot for the number of cases
  plot(P, type="o", bty="l", col="black", pch=16, cex=0.7, xlim=c(1,end_date), ylim=c(0, max(P, na.rm=T)),
       xlab="Day", ylab="Cases", main=paste("Cases in", location)) # Number of prevalent cases, P_t
  lines(I, type="o", pch=16, cex=0.7, col="blue") # Number of true cases, I_t
  lines(C, type="o", pch=16, cex=0.7, col="red") # Number of reported cases, C_t
  legend("topleft",legend = c("P_t","I_t","C_t"), col=c("black","blue","red"),
         pch=rep(16,3), lty=rep(1,3), bty="n")
  
  # Calculate the number of travelers, T_t (Ginny's version)
  Trav = rep(NA, end_date)  
  for(t in 2:end_date){
    Trav[t] = P[t] - cumsum(C)[t-1]
  } 
  Trav[1] <- P[1] # Number of infectious travelers on Day 1 = Number of prevalent cases on Day 1
  Trav <- ifelse(Trav <0, 0, Trav) # If negative, make it zero
  
  # Calculate the number of travelers (My version)
  Trav2 = rep(NA, end_date)
  for (t in 2:5) {
    Trav2[t] = P[t] - cumsum(C)[t-1]
  }
  for(t in 6:end_date){
    NotRecov <- c() 
    for (i in (t-4):(t-1)) {
      NotRecov[i] <- I[i]*(1-gamma_cdf[t-i])
    }
    for (i in 1:(t-5)) {
      NotRecov[i] <- (I[i]-C[i+d])*(1-gamma_cdf[t-i])
    }
    Trav2[t] <- sum(NotRecov) + I[t]
  }
  Trav2[1] <- P[1] # Number of infectious travelers on Day 1 = Number of prevalent cases on Day 1
  
  # Make a plot for the number of infectiuos travelers
  plot(P, type="o", bty="l", col="black", pch=16, cex=0.7, xlim=c(1,end_date),
       xlab="Day", ylab="Cases", main=paste("Infectious travelers in", location))
  lines(Trav,  type="l", col="darkgreen")
  lines(Trav2, type="l", col="darkgreen", lty=2)
  legend("topleft",legend = c("P_t","Ginny","Kayoko"), col=c("black","darkgreen","darkgreen"),
         pch=c(16,NA,NA), lty=c(1,1,2), bty="n")
  
  # Save results 
  all_Trav[,x+1]  <- Trav
  all_Trav2[,x+1] <- Trav2
  
}

# Save results in csv
write.csv(all_Trav,  file="InfectiousTravelers_Ginnys.csv", row.names = F)
write.csv(all_Trav2, file="InfectiousTravelers_Kayokos.csv", row.names = F)