import Foundation
import Combine

final class TestableGenericSubscriber<T, C>: Subscriber where C: Error {
    typealias Input = T
    typealias Failure = C
    
    typealias SubscriptionHook = (Subscription) -> ()
    typealias ReceiveInputHook = (T) -> (Subscribers.Demand)
    typealias ReceiveCompletionHook = (Subscribers.Completion<C>) -> ()
    
    private var subscriptionHook: SubscriptionHook
    private var inputHook: ReceiveInputHook
    private var completionHook: ReceiveCompletionHook
    
    init(subscriptionHook: @escaping SubscriptionHook = { subscription in
        print("Receive subscription", subscription)
        subscription.request(.max(1))
    },
         inputHook: @escaping ReceiveInputHook = { input in
        print("Received value", input)
        return .max(1)
    },
         completionHook: @escaping ReceiveCompletionHook = { completion in
        print("Received completion", completion)
    }) {
        
        self.subscriptionHook = subscriptionHook
        self.inputHook = inputHook
        self.completionHook = completionHook
    }
    
    func receive(subscription: Subscription) {
        subscriptionHook(subscription)
    }
    
    func receive(_ input: T) -> Subscribers.Demand {
        inputHook(input)
    }
    
    func receive(completion: Subscribers.Completion<C>) {
        completionHook(completion)
    }
}
