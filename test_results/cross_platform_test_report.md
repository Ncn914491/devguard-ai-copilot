# DevGuard AI Copilot - Cross-Platform Test Report

**Generated:** 2025-08-04T22:07:07.432517
**Platform:** windows "Windows 11 Home Single Language" 10.0 (Build 26100)
**Total Duration:** 0s

## Summary

| Metric | Value |
|--------|-------|
| Total Test Suites | 5 |
| Passed | 0 |
| Failed | 5 |
| Success Rate | 0.0% |

## Test Results

| Test Suite | Status | Duration | Errors |
|------------|--------|----------|--------|
| unit | ❌ Fail | 0s | 1 |
| widget | ❌ Fail | 0s | 1 |
| integration | ❌ Fail | 0s | 1 |
| platform | ❌ Fail | 0s | 1 |
| responsive | ❌ Fail | 0s | 1 |

## Error Details

### unit

```
ProcessException: The system cannot find the file specified.

  Command: flutter test test/ --reporter=json
```

### widget

```
ProcessException: The system cannot find the file specified.

  Command: flutter test test/cross_platform/responsive_ui_test.dart --reporter=json
```

### integration

```
ProcessException: The system cannot find the file specified.

  Command: flutter test integration_test/ --reporter=json
```

### platform

```
ProcessException: The system cannot find the file specified.

  Command: flutter test test/cross_platform/platform_specific_test.dart --reporter=json
```

### responsive

```
ProcessException: The system cannot find the file specified.

  Command: flutter test test/cross_platform/responsive_ui_test.dart --reporter=json
```

## Recommendations

⚠️ Some tests failed. Please review the error details above and fix the issues before deployment.

### Next Steps:
1. Review failed test details
2. Fix identified issues
3. Re-run tests to verify fixes
4. Update documentation if needed
