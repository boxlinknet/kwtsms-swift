import KwtSMS

let sms = KwtSMS.fromEnv()

// 1. Handle send errors
let result = await sms.send(mobile: "96598765432", message: "Test message")

switch result.result {
case "OK":
    print("Success! ID: \(result.msgId ?? "")")

case "ERROR":
    // Check the error code for specific handling
    switch result.code {
    case "ERR003":
        // Auth error: log it, alert admin, show generic message to user
        print("ADMIN ALERT: SMS auth failed. Check API credentials.")
        // User sees: "SMS service temporarily unavailable"

    case "ERR010", "ERR011":
        // Balance error: alert admin to top up
        print("ADMIN ALERT: SMS balance is low/zero. Recharge at kwtsms.com")

    case "ERR028":
        // Rate limit: tell user to wait
        print("Please wait before requesting another code.")

    case "ERR_INVALID_INPUT":
        // Show which numbers failed
        for entry in result.invalid {
            print("Invalid: \(entry.input) - \(entry.error)")
        }

    default:
        // Generic error with action guidance
        print("Error: \(result.description ?? "Unknown")")
        print("Action: \(result.action ?? "Contact support")")
    }

default:
    break
}

// 2. Handle verify errors
let verify = await sms.verify()
if !verify.ok {
    print("Credential check failed: \(verify.error ?? "")")
}

// 3. Check message status
let status = await sms.status(msgId: "some-msg-id")
if status.result == "ERROR" {
    print("Status error: \(status.description ?? "")")
    print("Action: \(status.action ?? "")")
}

// 4. Check delivery report (international only)
let dlr = await sms.deliveryReport(msgId: "some-msg-id")
if dlr.result == "ERROR" {
    print("DLR error: \(dlr.description ?? "")")
    // Kuwait numbers don't have DLR, only international
}
