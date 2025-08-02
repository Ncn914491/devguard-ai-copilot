#!/bin/bash

# Enhanced Security Monitoring Implementation Commit Script

echo "🔒 Committing Enhanced Security Monitoring Implementation..."

# Add all security monitoring related files
git add lib/core/security/security_monitor.dart
git add lib/core/ai/gemini_service.dart
git add test/security_monitoring_test.dart
git add test/security_copilot_integration_test.dart
git add scripts/commit_security_monitoring.sh

# Create detailed commit message
git commit -m "feat: Implement comprehensive security monitoring with AI-powered detection

🔒 Enhanced Security Detection:
- Honeytoken breach detection with immediate critical alerts
- Abnormal data export volume monitoring (baseline vs current)
- Configuration drift detection with change type analysis
- Login anomaly detection (floods, unusual sources, off-hours access)

🤖 AI-Powered Explanations:
- Gemini integration for contextual security alert explanations
- Severity-based recommendations and rollback suggestions
- Actionable security response guidance

🧪 Comprehensive Testing:
- Unit tests for all detection scenarios
- Integration tests with AI copilot system
- Rollback integration testing
- Evidence collection validation

📊 Key Features:
- Real-time baseline monitoring and anomaly detection
- Critical/High/Medium/Low severity classification
- Automatic rollback suggestions for critical events
- Comprehensive audit logging with AI reasoning
- Integration with copilot for security response

Satisfies Requirements: 3.1, 3.2, 3.3, 4.1, 4.2, 9.1, 9.2, 9.3, 9.4, 9.5"

echo "✅ Security monitoring implementation committed successfully!"
echo "📝 Commit includes:"
echo "   - Enhanced SecurityMonitor with 6 detection types"
echo "   - AI-powered explanation generation"
echo "   - Comprehensive test coverage"
echo "   - Integration with rollback system"
echo ""
echo "🚀 Ready for deployment and further development!"