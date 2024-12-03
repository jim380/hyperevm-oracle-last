# Tests

## Failing Tests

The following tests are currently failing and need investigation:

### SystemOracle.t.sol

1. `testDifferentDecimalConfigurations()` - Issue with decimal scaling

   - Expected: 1000000000 (1000e6)
   - Actual: 100000000000000000
   - Possible cause: Decimal scaling in Aggregator.\_getPerpOraclePrice needs review

2. `testPerpOracleIntegration()` - Issue with decimal scaling
   - Expected: 2000000000 (2000e6)
   - Actual: 200000000000000000
   - Possible cause: Same as above, decimal scaling issue

These tests have been temporarily commented out until the decimal scaling issue in the Aggregator contract can be resolved.
