import KwtSMS

let sms = KwtSMS.fromEnv()

// Generate a list of numbers (in practice, load from your database)
let numbers = (0..<500).map { "9655000\(String(format: "%04d", $0))" }

// sendBulk() auto-batches >200 numbers
let result = await sms.sendBulk(mobiles: numbers, message: "Campaign announcement from MyApp")

print("Result: \(result.result)")     // "OK", "PARTIAL", or "ERROR"
print("Batches: \(result.batches)")
print("Numbers sent: \(result.numbers)")
print("Credits used: \(result.pointsCharged)")
print("Balance: \(result.balanceAfter ?? 0)")
print("Message IDs: \(result.msgIds)")

if !result.errors.isEmpty {
    print("Batch errors:")
    for err in result.errors {
        print("  Batch \(err.batch): \(err.code) \(err.description)")
    }
}

if !result.invalid.isEmpty {
    print("Invalid numbers: \(result.invalid.count)")
}
