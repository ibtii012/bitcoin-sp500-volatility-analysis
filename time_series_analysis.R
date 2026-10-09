############################################################
# Time Series Analysis in Finance
# Project: Return Dynamics and Volatility in Bitcoin and the
# S&P 500: An ARIMA-GARCH Approach
############################################################

# ----------------------------------------------------------
# 1. Load required packages
# ----------------------------------------------------------

packages <- c("quantmod", "tseries", "forecast", "rugarch", "vars")

installed_packages <- rownames(installed.packages())

for (pkg in packages) {
  if (!(pkg %in% installed_packages)) {
    install.packages(pkg)
  }
}

library(quantmod)
library(tseries)
library(forecast)
library(rugarch)
library(vars)

# ----------------------------------------------------------
# 2. Import financial time series data
# ----------------------------------------------------------

# Data source: Yahoo Finance
# Assets:
# BTC-USD = Bitcoin price in USD
# ^GSPC = S&P 500 index

getSymbols("BTC-USD", from = "2018-01-01")
getSymbols("^GSPC", from = "2018-01-01")

# ----------------------------------------------------------
# 3. Extract closing prices and calculate log returns
# ----------------------------------------------------------

btc_price <- Cl(`BTC-USD`)
sp500_price <- Cl(GSPC)

# Remove missing observations
btc_price <- na.omit(btc_price)
sp500_price <- na.omit(sp500_price)

# Calculate daily log returns
btc_ret <- na.omit(diff(log(btc_price)))
sp500_ret <- na.omit(diff(log(sp500_price)))

# Align common trading dates
returns_data <- na.omit(merge(btc_ret, sp500_ret, join = "inner"))

colnames(returns_data) <- c("BTC_Returns", "SP500_Returns")

btc_ret <- returns_data$BTC_Returns
sp500_ret <- returns_data$SP500_Returns

# ----------------------------------------------------------
# 4. Visual inspection of log returns
# ----------------------------------------------------------

# Create 2-panel layout (1 column, 2 rows)
par(mfrow = c(2,1))

# Bitcoin
plot(btc_ret,
     main = "Bitcoin Log Returns",
     ylab = "Returns",
     col = "blue")

# S&P 500
plot(sp500_ret,
     main = "S&P 500 Log Returns",
     ylab = "Returns",
     col = "red")

# Reset layout back to normal 
par(mfrow = c(1,1))

# ----------------------------------------------------------
# 5. Stationarity testing using Augmented Dickey-Fuller test
# ----------------------------------------------------------

adf_btc <- adf.test(btc_ret)
adf_sp500 <- adf.test(sp500_ret)

adf_btc
adf_sp500

# ----------------------------------------------------------
# 6. Autocorrelation analysis
# ----------------------------------------------------------

acf(btc_ret, main = "ACF - Bitcoin Returns")
pacf(btc_ret, main = "PACF - Bitcoin Returns")

acf(sp500_ret, main = "ACF - S&P 500 Returns")
pacf(sp500_ret, main = "PACF - S&P 500 Returns")

# ----------------------------------------------------------
# 7. ARIMA modeling of return dynamics
# ----------------------------------------------------------

arima_btc <- auto.arima(btc_ret)
arima_sp500 <- auto.arima(sp500_ret)

summary(arima_btc)
summary(arima_sp500)

# ----------------------------------------------------------
# 8. Residual diagnostics for ARIMA models (Ljung-Box test)
# ----------------------------------------------------------

checkresiduals(arima_btc)
checkresiduals(arima_sp500)

# ----------------------------------------------------------
# 9. GARCH(1,1) modeling of volatility
# ----------------------------------------------------------

spec <- ugarchspec(
  variance.model = list(model = "sGARCH", garchOrder = c(1, 1)),
  mean.model = list(armaOrder = c(1, 1), include.mean = TRUE),
  distribution.model = "norm"
)

garch_btc <- ugarchfit(spec = spec, data = btc_ret)
garch_sp500 <- ugarchfit(spec = spec, data = sp500_ret)

garch_btc
garch_sp500

# ----------------------------------------------------------
# 10. Extract and compare conditional volatility
# ----------------------------------------------------------

vol_btc <- sigma(garch_btc)
vol_sp500 <- sigma(garch_sp500)

plot(vol_btc,
     col = "blue",
     main = "Conditional Volatility Comparison",
     ylab = "Conditional Volatility",
     xlab = "Date")

lines(vol_sp500, col = "red")

legend("topright",
       legend = c("Bitcoin", "S&P 500"),
       col = c("blue", "red"),
       lty = 1,
       bty = "n")

# ----------------------------------------------------------
# 11. Key model coefficients
# ----------------------------------------------------------

coef(garch_btc)
coef(garch_sp500)

# Volatility persistence
btc_persistence <- coef(garch_btc)["alpha1"] + coef(garch_btc)["beta1"]
sp500_persistence <- coef(garch_sp500)["alpha1"] + coef(garch_sp500)["beta1"]

btc_persistence
sp500_persistence


# ----------------------------------------------------------
# 12. Granger causality test on conditional volatility
# ----------------------------------------------------------

# Combine conditional volatility series
vol_data <- merge(vol_btc, vol_sp500)

# Rename columns
colnames(vol_data) <- c("BTC_Volatility", "SP500_Volatility")

# Remove missing values
vol_data <- na.omit(vol_data)

# Select optimal lag length for VAR model
lag_selection <- VARselect(vol_data, lag.max = 10, type = "const")
lag_selection$selection

# Estimate VAR model using AIC-selected lag length
selected_lag <- lag_selection$selection["AIC(n)"]

var_model <- VAR(vol_data, p = selected_lag, type = "const")

# Granger causality tests
causality(var_model, cause = "BTC_Volatility")
causality(var_model, cause = "SP500_Volatility")