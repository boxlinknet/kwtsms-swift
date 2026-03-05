# OTP Flow

Demonstrates generating and sending OTP codes following kwtSMS best practices:
- Always include app name in the message
- Generate a new code on each resend
- Enforce minimum 3-minute resend timer
- Use a Transactional sender ID for OTP
