//
// Copyright (c) 2022 Adyen N.V.
//
// This file is open source and available under the MIT license. See the LICENSE file for more info.
//


import Adyen
import Foundation
import PassKit
import React

@objc(AdyenApplePay)
final internal class ApplePayComponent: BaseModule {
    
    override func supportedEvents() -> [String]! { super.supportedEvents() }

    @objc
    func hide(_ success: NSNumber, event: NSDictionary) {
        dismiss(success.boolValue)
    }

    @objc
    func open(_ paymentMethodsDict: NSDictionary, configuration: NSDictionary) {
        let parser = RootConfigurationParser(configuration: configuration)
        let applePayParser = ApplepayConfigurationParser(configuration: configuration)
        let paymentMethod: ApplePayPaymentMethod
        let clientKey: String
        let payment: Payment
        let applepayConfig: Adyen.ApplePayComponent.Configuration
        do {
            paymentMethod = try parsePaymentMethod(from: paymentMethodsDict, for: ApplePayPaymentMethod.self)
            clientKey = try fetchClientKey(from: parser)
            payment = try fetchPayment(from: parser)
            applepayConfig = try applePayParser.buildConfiguration(amount: payment.amount)
        } catch {
            return sendEvent(error: error)
        }
        

        let apiContext = APIContext(environment: parser.environment, clientKey: clientKey)
        let applePayComponent: Adyen.ApplePayComponent
        do {
            applePayComponent = try Adyen.ApplePayComponent(paymentMethod: paymentMethod,
                                                        apiContext: apiContext,
                                                        payment: payment,
                                                        configuration: applepayConfig)
        } catch {
            return sendEvent(error: error)
        }

        present(component: applePayComponent)
    }

}

extension ApplePayComponent: PaymentComponentDelegate {

    internal func didSubmit(_ data: PaymentComponentData, from component: PaymentComponent) {
        // Extract the shipping address from the data
        if let shippingContact = data.paymentMethod.encodable as? ApplePayKeys.shippingContact,
        let postalAddress = shippingContact.postalAddress {
            
            // Perform the validation on the postal address
            if !isValid(postalAddress: postalAddress) {
                // Cancel the payment if the address is not valid
                cancelPayment(from: component)
                sendEvent(event: .didFail, body: ["error": "Invalid postal address"])
                return
            }
            sendEvent(event: .didSubmit, body: data.jsonObject)
        }
    }

    private func isValid(postalAddress: CNPostalAddress) -> Bool {
    // Check if the street property is available
        guard let street = postalAddress.street else {
            return false
        }

        if street.count > 50 {
            return false
        }

        let components = street.split(separator: " ")
        
        if components.count < 2 {
            return false
        }
        
        // Check that the first component (assumed to be the street number) is a number
        if let streetNumber = components.first, Int(streetNumber) == nil {
            return false
        }

        return true
    }



    internal func didFail(with error: Error, from component: PaymentComponent) {
        sendEvent(error: error)
    }

}
