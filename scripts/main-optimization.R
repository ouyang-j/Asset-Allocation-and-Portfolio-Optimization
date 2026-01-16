library(ggplot2)
library(reshape2)
library(MASS)
##################################################################################
# Set seed for reproducibility, I use my student ID for uniqueness
set.seed(2528985)

# Instead of uniform distribution, most wealth should be around 80M or 100M
raw_points <- rlnorm(n = 1000, meanlog = log(80), sdlog = 0.8)
grid <- sort(unique(c(0:150, raw_points)))
summary(grid)
hist(grid, breaks=50, main="Grid Density (0-200M)", xlab="Wealth ($M)")

##################################################################################
# Define the Piecewise Utility Function
get_utility <- function(W) {
  # Range: Very successful (Min $110)
  if (W >= 110) {
    return(5.8 * ((W^0.5 - 1) / 0.5))
    
    # Range: Successful (Min $100, Max $110)
  } else if (W >= 100) {
    return(W)
    
    # Range: Somewhat disappointing (Min $95, Max $100)
  } else if (W >= 95) {
    return(1.01 * (W - exp(-0.001 * (100 - W))))
    
    # Range: Very disappointing (Min $0, Max $95)
  } else {
    return(W - 0.2 * (95 - W)^2)
  }
}

V_terminal <- sapply(grid, get_utility)
# Plotting the Utility Function to see the shape and risk preferences
plot(grid, V_terminal, type="l", col="blue", lwd=2,
     main="Terminal Utility Function V_T(W)",
     xlab="Wealth ($ Millions)", ylab="Utility")
grid()
abline(v=c(95), col="red", lty=2) # Mark the critical thresholds
abline(h=c(0), col="purple", lty=2)
##################################################################################
# Statistics (Mean and Stdev of the underlying Normal) 
mu_vec <- c(0.057, 0.054, 0.052, 0.050, 0.033, 0.063, 0.028)
sd_vec <- c(0.176, 0.187, 0.243, 0.192, 0.037, 0.066, 0.056)
asset_names <- c("US_Stock", "Dev_Intl", "Emer_Mkt", "Global_RE", 
                 "US_Agg_Bond", "Hedge_Fund", "Cash")

cor_data <- c(
  1.00, 0.00, 0.00, 0.00, 0.00, 0.00, 0.00,  # US Stock
  0.74, 1.00, 0.00, 0.00, 0.00, 0.00, 0.00,  # Dev Intl
  0.67, 0.70, 1.00, 0.00, 0.00, 0.00, 0.00,  # Emer Mkt
  0.74, 0.78, 0.66, 1.00, 0.00, 0.00, 0.00,  # Global RE
  0.13, 0.09, 0.07, 0.10, 1.00, 0.00, 0.00,  # US Agg
  0.47, 0.46, 0.45, 0.37, 0.10, 1.00, 0.00,  # Hedge Fund
  0.02, 0.00, -0.03,-0.03, 0.10, 0.55, 1.00  # Cash
)

# Create the matrix and fill the upper triangle to make it symmetric
cor_mat <- matrix(cor_data, nrow=7, ncol=7, byrow=TRUE)
cor_mat[upper.tri(cor_mat)] <- t(cor_mat)[upper.tri(cor_mat)]

# Convert to Covariance Matrix: Sigma = diag(sd) * rho * diag(sd)
cov_mat <- diag(sd_vec) %*% cor_mat %*% diag(sd_vec)

# Generate Correlated Log-Returns
set.seed(2528985)
log_returns <- mvrnorm(n = 5000, mu = mu_vec, Sigma = cov_mat)

# Convert to Simple Returns: R = exp(log_returns) - 1
correlated_returns <- exp(log_returns) - 1
colnames(correlated_returns) <- asset_names

print(head(correlated_returns))


##################################################################################

# 1. Define the Flows (Donations - Spending) from Source 12
# Year 1 to Year 10
donations <- c(2.0, 2.2, 2.4, 2.8, 3.2, 3.6, 3.5, 3.4, 3.4, 3.4)
spending  <- c(1.7, 1.8, 1.9, 2.0, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7)
net_flows <- donations - spending # Vector of length 10

# 2. Define the 7 Investment Mixes (Weights) from Source 28
# Columns: US Stk, Dev Intl, Emer Mkt, REIT, Bond, Hedge, Cash
weights <- matrix(c(
  0.00, 0.00, 0.00, 0.00, 0.70, 0.08, 0.22, # Mix 1
  0.00, 0.00, 0.00, 0.00, 0.57, 0.43, 0.00, # Mix 2
  0.00, 0.00, 0.00, 0.00, 0.34, 0.66, 0.00, # Mix 3
  0.00, 0.00, 0.00, 0.00, 0.12, 0.88, 0.00, # Mix 4
  0.03, 0.00, 0.16, 0.00, 0.00, 0.81, 0.00, # Mix 5
  0.06, 0.00, 0.42, 0.00, 0.00, 0.52, 0.00, # Mix 6
  0.09, 0.00, 0.69, 0.00, 0.00, 0.22, 0.00  # Mix 7
), nrow=7, byrow=TRUE)

# 3. Pre-calculate Portfolio Returns (Crucial for Speed)
# We assume 'correlated_returns' (5000 x 7) exists from the previous step
# Result: 'sim_returns' is a 5000 x 7 matrix where col 1 is returns for Mix 1
sim_returns <- correlated_returns %*% t(weights)

# ==============================================================================
# STEP 1: INITIALIZE
# ==============================================================================

# Create matrices to store the results
# Rows = Grid Points (Wealth), Cols = Time Steps (0 to 9)
n_grid <- length(grid)
policy_matrix <- matrix(NA, nrow=n_grid, ncol=10) # Stores optimal Mix ID
value_matrix  <- matrix(NA, nrow=n_grid, ncol=11) # Stores Value Function (0..10)

# Initialize V_next with Terminal Utility (calculated previously)
V_next <- V_terminal 
value_matrix[, 11] <- V_next # Store V_10 for reference
# ==============================================================================
# STEP 2: THE BACKWARD RECURSION (With Subsampling)
# ==============================================================================

# Define sample size per iteration as requested
n_subsample <- 500
total_scenarios <- nrow(sim_returns) # Should be 5000 from previous step

# Loop from t = 9 down to 0
for (t in 9:0) {
 
  V_current <- numeric(n_grid)
  
  # [cite_start]Get flow for upcoming year [cite: 12]
  flow_t <- net_flows[t + 1] 
  
  # ============================
  # SPACE LOOP: For each Wealth Point
  # ============================
  for (i in 1:n_grid) {
    w <- grid[i]
    w_investable <- w + flow_t
    
    # --- RANDOM SAMPLING (CRN) ---
    # Randomly choose 500 indices from the 5000 available scenarios.
    # We do this HERE so all 7 mixes face the exact same market conditions
    # for this specific grid point calculation.
    sample_idx <- sample(1:total_scenarios, n_subsample)
    
    expected_values <- numeric(7)
    
    # ============================
    # [cite_start]ACTION LOOP: For each Mix [cite: 25]
    # ============================
    for (k in 1:7) {
      # 1. Select the SUBSET of returns for Mix k
      R_vec <- sim_returns[sample_idx, k]
      
      # 2. Calculate Future Wealth
      w_future <- w_investable * (1 + R_vec)
      
      # 3. Interpolate using V_next
      # Map future outcomes to utility values
      v_outcomes <- approx(x = grid, y = V_next, xout = w_future, rule = 2)$y
      
      # 4. Compute Average (Expected Value)
      # We assume equal probability for these 500 sampled scenarios
      expected_values[k] <- mean(v_outcomes)
    }
    
    # ============================
    # MAXIMIZATION
    # ============================
    best_value <- max(expected_values)
    best_mix   <- which.max(expected_values)
    
    V_current[i]      <- best_value
    policy_matrix[i, t+1] <- best_mix
  }
  
  # ============================
  # UPDATE
  # ============================
  V_next <- V_current
  value_matrix[, t+1] <- V_current
}
##################################################################################


quantile(grid)
samp_idx_grid <- c(which.min(abs(grid-0)), which.min(abs(grid-20)), which.min(abs(grid-48.9009)), which.min(abs(grid-60)),which.min(abs(grid-82.86119)), which.min(abs(grid-134.25921)), which.min(abs(grid-820.79219)))
policy_matrix[samp_idx_grid,]

##################################################################################
# 1. Simulation Setup
n_sim_forward <- 5000  # Number of paths to simulate
T_years <- 10
initial_wealth <- 40   # Starting assets $40M 

# Storage matrices
# Wealth paths: Rows = Sims, Cols = Time 0 to 10
sim_wealth <- matrix(NA, nrow=n_sim_forward, ncol=T_years + 1)
sim_wealth[, 1] <- initial_wealth

# Mix choices: Rows = Sims, Cols = Time 0 to 9 (Decisions)
sim_mixes <- matrix(NA, nrow=n_sim_forward, ncol=T_years)

# 2. Generate NEW Market Scenarios for the Forward Pass
# We generate T_years * n_sim_forward random returns for all assets
# (Using the same mu_vec and cov_mat defined in previous steps)
set.seed(2528985) # Different seed for validation
total_draws <- n_sim_forward * T_years
forward_log_rets <- mvrnorm(n = total_draws, mu = mu_vec, Sigma = cov_mat)
forward_simple_rets <- exp(forward_log_rets) - 1

# 3. The Forward Loop (Time 0 -> 9)
# ------------------------------------------------------------------------------
for (t in 0:(T_years - 1)) {
  
  # Get the flow for the upcoming year (Donations - Spending)
  # Remember: Flows occur at the beginning of the year [cite: 13]
  flow_t <- net_flows[t + 1]
  
  # Extract the random returns for this specific year 't' for all 'sims'
  # Logic: Rows (t*n_sim + 1) to ((t+1)*n_sim)
  start_idx <- t * n_sim_forward + 1
  end_idx   <- (t + 1) * n_sim_forward
  year_asset_returns <- forward_simple_rets[start_idx:end_idx, ]
  
  for (m in 1:n_sim_forward) {
    # A. Current Wealth
    w_curr <- sim_wealth[m, t + 1]
    
    # B. Apply Policy (Look up optimal mix)
    # Find the index in the grid closest to current wealth
    # (We restrict range to grid bounds to prevent indexing errors)
    w_bounded <- max(min(w_curr, max(grid)), min(grid))
    grid_idx  <- which.min(abs(grid - w_bounded))
    
    # Get optimal mix from the Policy Matrix derived in Step 2
    # policy_matrix col 1 is for t=0, col 10 is for t=9
    chosen_mix <- policy_matrix[grid_idx, t + 1]
    sim_mixes[m, t + 1] <- chosen_mix
    
    # C. Calculate Portfolio Return
    # Get weights for the chosen mix
    mix_weights <- weights[chosen_mix, ]
    # Calculate portfolio return for this specific simulation 'm'
    port_ret <- sum(year_asset_returns[m, ] * mix_weights)
    
    # D. Evolve Wealth
    # W_next = (W_curr + Flow) * (1 + R_p)
    w_next <- (w_curr + flow_t) * (1 + port_ret)
    sim_wealth[m, t + 2] <- w_next
  }
}

# ==============================================================================
# STEP 5: VISUALIZATION
# ==============================================================================

# A. Prepare Data for Plotting
# Convert matrix to long format for ggplot
df_wealth <- melt(sim_wealth)
colnames(df_wealth) <- c("SimID", "Year", "Wealth")
df_wealth$Year <- df_wealth$Year - 1 # Adjust to 0-10 scale

# Highlight 5 specific paths
highlight_ids <- 1:5
df_highlight <- subset(df_wealth, SimID %in% highlight_ids)

# B. Plot Wealth Paths
p1 <- ggplot() +
  # Plot all paths in faint grey
  geom_line(data = df_wealth, aes(x=Year, y=Wealth, group=SimID), 
            color="grey80", alpha=0.1) +
  # Highlight a few specific paths
  geom_line(data = df_highlight, aes(x=Year, y=Wealth, color=as.factor(SimID)), 
            size=1) +
  # Add Target Line ($100M)
  geom_hline(yintercept=100, color="red", linetype="dashed", size=1) +
  # Add Starting Line ($40M)
  geom_hline(yintercept=40, color="blue", linetype="dotted") +
  
  scale_y_continuous(limits=c(0, 200), oob=scales::squish) +
  labs(title="10-Year Wealth Simulations (Optimal Mix Choice)",
       subtitle="Grey = 5000 Simulations | Colored = 5 Random Paths",
       y="Wealth ($ Millions)", x="Year") +
  theme_minimal() +
  theme(legend.position="none")

print(p1)

# C. Plot Mix Choices for ONE Path (e.g., Path #1)
# This helps explain the "Why" behind the results
path_id <- 749
mix_data <- data.frame(
  Year = 0:9,
  Wealth = sim_wealth[path_id, 1:10],
  Mix = sim_mixes[path_id, ]
)

p2 <- ggplot(mix_data, aes(x=Year, y=Wealth)) +
  geom_line(color="black") +
  geom_point(aes(color=as.factor(Mix)), size=5) +
  scale_color_brewer(palette="Set1", name="Mix Choice") +
  labs(title=paste("Strategy Drill-Down: Simulation #", path_id),
       subtitle="Dots indicate the Portfolio Mix chosen at each year",
       y="Wealth ($ Millions)") +
  geom_hline(yintercept=100, linetype="dashed", color="red") +
  theme_bw()

print(p2)

# D. Terminal Wealth Statistics
final_wealth <- sim_wealth[, 11]
cat("=== Simulation Results ===\n")
cat("Probability of reaching $100M:", mean(final_wealth >= 100) * 100, "%\n")
cat("Median Terminal Wealth:", median(final_wealth), "M\n")
cat("Worst Case (5th Percentile):", quantile(final_wealth, 0.05), "M\n")
cat("Best Case (95th Percentile):", quantile(final_wealth, 0.95), "M\n")
