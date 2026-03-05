import KwtSMS

// Create client from environment variables
let sms = KwtSMS.fromEnv()

// Verify credentials
let verify = await sms.verify()
if verify.ok {
    print("Connected! Balance: \(verify.balance!) credits")
} else {
    print("Error: \(verify.error!)")
    // exit early
}

// List sender IDs
let senders = await sms.senderIds()
if senders.result == "OK" {
    print("Sender IDs: \(senders.senderIds.joined(separator: ", "))")
}

// Check coverage
let coverage = await sms.coverage()
if coverage.result == "OK" {
    print("Active prefixes: \(coverage.prefixes.joined(separator: ", "))")
}

// Send an SMS
let result = await sms.send(mobile: "96598765432", message: "Hello from kwtSMS Swift!")
if result.result == "OK" {
    print("Sent! Message ID: \(result.msgId ?? "")")
    print("Balance remaining: \(result.balanceAfter ?? 0)")
} else {
    print("Send failed: \(result.description ?? "")")
    print("Action: \(result.action ?? "")")
}
