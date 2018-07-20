//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

import Foundation

@objc(OWSContactDiscoveryOperation)
class ContactDiscoveryOperation: OWSOperation, LegacyContactDiscoveryBatchOperationDelegate {

    let batchSize = 2048
    let recipientIdsToLookup: [String]

    @objc
    var registeredRecipientIds: Set<String>

    @objc
    required init(recipientIdsToLookup: [String]) {
        self.recipientIdsToLookup = recipientIdsToLookup
        self.registeredRecipientIds = Set()

        super.init()

        Logger.debug("\(logTag) in \(#function) with recipientIdsToLookup: \(recipientIdsToLookup.count)")
        for batchIds in recipientIdsToLookup.chunked(by: batchSize) {
            let batchOperation = LegacyContactDiscoveryBatchOperation(recipientIdsToLookup: batchIds)
            batchOperation.delegate = self
            self.addDependency(batchOperation)
        }
    }

    // MARK: Mandatory overrides

    // Called every retry, this is where the bulk of the operation's work should go.
    override func run() {
        Logger.debug("\(logTag) in \(#function)")

        for dependency in self.dependencies {
            guard let batchOperation = dependency as? LegacyContactDiscoveryBatchOperation else {
                owsFail("\(self.logTag) in \(#function) unexpected dependency: \(dependency)")
                continue
            }

            self.registeredRecipientIds.formUnion(batchOperation.registeredRecipientIds)
        }

        self.reportSuccess()
    }

    // MARK: LegacyContactDiscoveryBatchOperationDelegate
    func contactDiscoverBatchOperation(_ contactDiscoverBatchOperation: LegacyContactDiscoveryBatchOperation, didFailWithError error: Error) {
        Logger.debug("\(logTag) in \(#function) canceling self and all dependencies.")

        self.dependencies.forEach { $0.cancel() }
        self.cancel()
    }
}

protocol LegacyContactDiscoveryBatchOperationDelegate: class {
    func contactDiscoverBatchOperation(_ contactDiscoverBatchOperation: LegacyContactDiscoveryBatchOperation, didFailWithError error: Error)
}

class LegacyContactDiscoveryBatchOperation: OWSOperation {

    var registeredRecipientIds: Set<String>
    weak var delegate: LegacyContactDiscoveryBatchOperationDelegate?

    private let recipientIdsToLookup: [String]
    private var networkManager: TSNetworkManager {
        return TSNetworkManager.shared()
    }

    // MARK: Initializers

    required init(recipientIdsToLookup: [String]) {
        self.recipientIdsToLookup = recipientIdsToLookup
        self.registeredRecipientIds = Set()

        super.init()

        Logger.debug("\(logTag) in \(#function) with recipientIdsToLookup: \(recipientIdsToLookup.count)")
    }

    // MARK: OWSOperation Overrides

    // Called every retry, this is where the bulk of the operation's work should go.
    override func run() {
        Logger.debug("\(logTag) in \(#function)")

        guard !isCancelled else {
            Logger.info("\(logTag) in \(#function) no work to do, since we were canceled")
            self.reportCancelled()
            return
        }

        var phoneNumbersByHashes: [String: String] = [:]

        for recipientId in recipientIdsToLookup {
            let hash = Cryptography.truncatedSHA1Base64EncodedWithoutPadding(recipientId)
            assert(phoneNumbersByHashes[hash] == nil)
            phoneNumbersByHashes[hash] = recipientId
        }

        let hashes: [String] = Array(phoneNumbersByHashes.keys)

        let request = OWSRequestFactory.contactsIntersectionRequest(withHashesArray: hashes)

        self.networkManager.makeRequest(request,
                                        success: { (task, responseDict) in
                                            do {
                                                self.registeredRecipientIds = try self.parse(response: responseDict, phoneNumbersByHashes: phoneNumbersByHashes)
                                                self.reportSuccess()
                                            } catch {
                                                self.reportError(error)
                                            }
        },
                                        failure: { (task, error) in
                                            guard let response = task.response as? HTTPURLResponse else {
                                                let responseError: NSError = OWSErrorMakeUnableToProcessServerResponseError() as NSError
                                                responseError.isRetryable = true
                                                self.reportError(responseError)
                                                return
                                            }

                                            guard response.statusCode != 413 else {
                                                let rateLimitError = OWSErrorWithCodeDescription(OWSErrorCode.contactsUpdaterRateLimit, "Contacts Intersection Rate Limit")
                                                self.reportError(rateLimitError)
                                                return
                                            }

                                            self.reportError(error)
        })
    }

    // Called at most one time.
    override func didSucceed() {
        // Compare against new CDS service
        let newCDSBatchOperation = CDSBatchOperation(recipientIdsToLookup: self.recipientIdsToLookup)
        let cdsFeedbackOperation = CDSFeedbackOperation(legacyRegisteredRecipientIds: self.registeredRecipientIds)
        cdsFeedbackOperation.addDependency(newCDSBatchOperation)

        CDSFeedbackOperation.operationQueue.addOperations([newCDSBatchOperation, cdsFeedbackOperation], waitUntilFinished: false)
    }

    // Called at most one time.
    override func didFail(error: Error) {
        self.delegate?.contactDiscoverBatchOperation(self, didFailWithError: error)
    }

    // MARK: Private Helpers

    private func parse(response: Any?, phoneNumbersByHashes: [String: String]) throws -> Set<String> {

        guard let responseDict = response as? [String: AnyObject] else {
            let responseError: NSError = OWSErrorMakeUnableToProcessServerResponseError() as NSError
            responseError.isRetryable = true

            throw responseError
        }

        guard let contactDicts = responseDict["contacts"] as? [[String: AnyObject]] else {
            let responseError: NSError = OWSErrorMakeUnableToProcessServerResponseError() as NSError
            responseError.isRetryable = true

            throw responseError
        }

        var registeredRecipientIds: Set<String> = Set()

        for contactDict in contactDicts {
            guard let hash = contactDict["token"] as? String, hash.count > 0 else {
                owsFail("\(self.logTag) in \(#function) hash was unexpectedly nil")
                continue
            }

            guard let recipientId = phoneNumbersByHashes[hash], recipientId.count > 0 else {
                owsFail("\(self.logTag) in \(#function) recipientId was unexpectedly nil")
                continue
            }

            guard recipientIdsToLookup.contains(recipientId) else {
                owsFail("\(self.logTag) in \(#function) unexpected recipientId")
                continue
            }

            registeredRecipientIds.insert(recipientId)
        }

        return registeredRecipientIds
    }

}

class CDSBatchOperation: OWSOperation {

    private let recipientIdsToLookup: [String]
    var registeredRecipientIds: Set<String>

    private var networkManager: TSNetworkManager {
        return TSNetworkManager.shared()
    }

    // MARK: Initializers

    required init(recipientIdsToLookup: [String]) {
        self.recipientIdsToLookup = recipientIdsToLookup
        self.registeredRecipientIds = Set()

        super.init()

        Logger.debug("\(logTag) in \(#function) with recipientIdsToLookup: \(recipientIdsToLookup.count)")
    }

    // MARK: OWSOperationOverrides

    // Called every retry, this is where the bulk of the operation's work should go.
    override func run() {
        Logger.debug("\(logTag) in \(#function)")

        guard !isCancelled else {
            Logger.info("\(logTag) in \(#function) no work to do, since we were canceled")
            self.reportCancelled()
            return
        }

        let cds = ContactDiscoveryService.shared()
        cds.performRemoteAttestation(success: { (remoteAttestation: RemoteAttestation) in
            self.makeContactDiscoveryRequest(remoteAttestation: remoteAttestation)
        },
                                     failure: self.reportError)
    }

    private func makeContactDiscoveryRequest(remoteAttestation: RemoteAttestation) {

        guard !isCancelled else {
            Logger.info("\(logTag) in \(#function) no work to do, since we were canceled")
            self.reportCancelled()
            return
        }

        let encryptionResult: AddressEncryptionResult
        do {
            encryptionResult = try encryptedAddresses(recipientIds: Set(self.recipientIdsToLookup), remoteAttestation: remoteAttestation)
        } catch {
            reportError(error)
            return
        }

        /*
         Request:
         requestId:        (variable length, base64) the decrypted ciphertext from the Remote Attestation response
         addressCount:    (integer from 1 to 2048) count of phone numbers in request
         data:            ((addressCount*8) bytes, base64) array of normalized international phone numbers, encoded numerically as 64-bit big-endian integers
         (data, mac) = AES-256-GCM(key=client_key, plaintext=phoneArray, AAD=requestId, iv=secureRandom())
         iv:            (12 bytes, base64) Client-chosen IV for encrypted data
         mac:            (16 bytes, base64) MAC for encrypted data
         */
        let request = OWSRequestFactory.enclaveContactDiscoveryRequest(withId: remoteAttestation.requestId,
                                                                       addressCount: encryptionResult.addressCount,
                                                                       encryptedAddressData: encryptionResult.encryptedAddressData,
                                                                       cryptIv: encryptionResult.initializationVector,
                                                                       cryptMac: encryptionResult.authTag,
                                                                       enclaveId: remoteAttestation.enclaveId,
                                                                       authUsername: remoteAttestation.authUsername,
                                                                       authPassword: remoteAttestation.authToken,
                                                                       cookies: remoteAttestation.cookies)

        self.networkManager.makeRequest(request,
                                        success: { (task, responseDict) in
                                            do {
                                                self.registeredRecipientIds = try self.parse(response: responseDict)
                                                self.reportSuccess()
                                            } catch {
                                                self.reportError(error)
                                            }
        },
                                        failure: { (task, error) in
                                            guard let response = task.response as? HTTPURLResponse else {
                                                let responseError: NSError = OWSErrorMakeUnableToProcessServerResponseError() as NSError
                                                responseError.isRetryable = true
                                                self.reportError(responseError)
                                                return
                                            }

                                            guard response.statusCode != 413 else {
                                                let rateLimitError = OWSErrorWithCodeDescription(OWSErrorCode.contactsUpdaterRateLimit, "Contacts Intersection Rate Limit")
                                                self.reportError(rateLimitError)
                                                return
                                            }

                                            self.reportError(error)
        })
    }

    struct AddressEncryptionResult {
        let addressCount: UInt
        let encryptedAddressData: Data
        let initializationVector: Data
        let authTag: Data
    }

    func encryptedAddresses(recipientIds: Set<String>, remoteAttestation: RemoteAttestation) throws -> AddressEncryptionResult {

        /*
         Request:
         requestId:        (variable length, base64) the decrypted ciphertext from the Remote Attestation response
         addressCount:    (integer from 1 to 2048) count of phone numbers in request
         data:            ((addressCount*8) bytes, base64) array of normalized international phone numbers, encoded numerically as 64-bit big-endian integers
         (data, mac) = AES-256-GCM(key=client_key, plaintext=phoneArray, AAD=requestId, iv=secureRandom())
         iv:            (12 bytes, base64) Client-chosen IV for encrypted data
         mac:            (16 bytes, base64) MAC for encrypted data
        */

        let addressCount: UInt = UInt(recipientIds.count)

        let addressPlainTextData = encodePhoneNumbers(recipientIds: recipientIds)

        guard let encryptionResult = Cryptography.encryptAESGCM(with: addressPlainTextData, key: remoteAttestation.keys.clientKey) else {
            throw CDSBatchOperationError.assertionError(description: "Encryption failure")
        }

        return AddressEncryptionResult(addressCount: addressCount,
                                       encryptedAddressData: encryptionResult.ciphertext,
                                       initializationVector: encryptionResult.initializationVector,
                                       authTag: encryptionResult.authTag)
    }

    func encodePhoneNumbers(recipientIds: Set<String>) -> Data {
        var output = Data()

        recipientIds.compactMap { recipientId in
            guard recipientId.prefix(1) == "+" else {
                owsFail("\(self.logTag) in \(#function) unexpected initial char in")
                return nil
            }

            let numericPortionIndex = recipientId.index(after: recipientId.startIndex)
            let numericPortion = recipientId.suffix(from: numericPortionIndex)

            guard let numericIdentifier = UInt64(numericPortion), numericIdentifier > 99 else {
                owsFail("\(self.logTag) in \(#function) unexpectedly short identifier")
                return nil
            }

            return numericIdentifier
        }.forEach { (numericIdentifier: UInt64) in
            var bigEndian: UInt64 = CFSwapInt64HostToBig(numericIdentifier)
            let buffer = UnsafeBufferPointer(start: &bigEndian, count: 1)
            output.append(buffer)
        }

        return output
    }

    enum CDSBatchOperationError: Error {
        case parseError(description: String)
        case assertionError(description: String)
    }

    func parse(response: Any?) throws -> Set<String> {
        /*
        Response:
        A successful (HTTP 200) response json object consists of:
        data:            ((addressCount) bytes, base64) list of boolean values, where zero is false and non-zero is true, with one boolean for each input phone number in the same order, indicating whether a signal user exists for that phone number or not
        (data, mac) = AES-256-GCM(key=server_key, plaintext=resultBoolArray, AAD=(), iv)
        iv:            (12 bytes, base64) Server-chosen IV for encrypted data
            mac:            (16 bytes, base64) MAC for encrypted data
        */
        throw CDSBatchOperationError.parseError(description: "unimplemented")
    }
}

class CDSFeedbackOperation: OWSOperation {

    static let operationQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1

        return queue
    }()

    private let legacyRegisteredRecipientIds: Set<String>

    // MARK: Initializers

    required init(legacyRegisteredRecipientIds: Set<String>) {
        self.legacyRegisteredRecipientIds = legacyRegisteredRecipientIds

        super.init()

        Logger.debug("\(logTag) in \(#function)")
    }

    // MARK: OWSOperation Overrides

    // Called every retry, this is where the bulk of the operation's work should go.
    override func run() {
        guard let cdsOperation = dependencies.first as? CDSBatchOperation else {
            let error = OWSErrorMakeAssertionError("\(self.logTag) in \(#function) cdsOperation was unexpectedly nil")
            self.reportError(error)
            return
        }

        let cdsRegisteredRecipientIds = cdsOperation.registeredRecipientIds

        if cdsRegisteredRecipientIds == legacyRegisteredRecipientIds {
            Logger.debug("\(logTag) in \(#function) TODO: PUT /v1/directory/feedback/ok")
        } else {
            Logger.debug("\(logTag) in \(#function) TODO: PUT /v1/directory/feedback/mismatch")
        }

        self.reportSuccess()
    }

    override func didFail(error: Error) {
        // dependency failed.
        // Depending on error, PUT one of:
        // /v1/directory/feedback/server-error:
        // /v1/directory/feedback/client-error:
        // /v1/directory/feedback/attestation-error:
        // /v1/directory/feedback/unexpected-error:
        Logger.debug("\(logTag) in \(#function) TODO: PUT /v1/directory/feedback/*-error")
    }
}

extension Array {
    func chunked(by chunkSize: Int) -> [[Element]] {
        return stride(from: 0, to: self.count, by: chunkSize).map {
            Array(self[$0..<Swift.min($0 + chunkSize, self.count)])
        }
    }
}
