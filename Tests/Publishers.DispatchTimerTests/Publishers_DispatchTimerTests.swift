import XCTest
import Combine
@testable import Publishers_DispatchTimer

final class Publishers_DispatchTimerTests: XCTestCase {
    
    func testTimerSubscription() throws {
        let expectation = XCTestExpectation(description: "Receive subscription.")
        let timerPublisher = Publishers.timer(interval: .seconds(1))
        let timerSubscriber = TestableGenericSubscriber<DispatchTime, Never>.init(
            subscriptionHook:  { subscription in
                subscription.request(.max(5))
                print("Receive subscription: ", subscription)
            },
            inputHook:  { input in
                print("Receive input: ", input)
                return .none
            },
            completionHook: { completion in
                print("Receive completion: ", completion)
                XCTAssert(completion == .finished)
                expectation.fulfill()
            })
        
        timerPublisher.subscribe(timerSubscriber)
        
        wait(for: [expectation], timeout: 7.0)
    }
    
    func testTimerInput() throws {
        let expectation = XCTestExpectation(description: "Receive input.")
        let timerPublisher = Publishers.timer(interval: .seconds(1), repeatTimes: .max(5))
        let timerSubscriber = TestableGenericSubscriber<DispatchTime, Never>.init(
            subscriptionHook:  { subscription in
                subscription.request(.max(1))
                print("Receive subscription: ", subscription)
            },
            inputHook:  { input in
                print("Receive input: ", input)
                return .max(1)
            },
            completionHook: { completion in
                print("Receive completion: ", completion)
                XCTAssert(completion == .finished)
                expectation.fulfill()
            })
        
        timerPublisher.subscribe(timerSubscriber)
        
        wait(for: [expectation], timeout: 7.0)
    }
    
    func testTimerMaxRepeatTimes() throws {
        let expectation = XCTestExpectation(description: "Receive completion after max repeat times")
        let timerPublisher = Publishers.timer(interval: .seconds(1), repeatTimes: .max(5))
        let timerSubscriber = TestableGenericSubscriber<DispatchTime, Never>.init(
            subscriptionHook:  { subscription in
                subscription.request(.max(10))
                print("Receive subscription: ", subscription)
            },
            completionHook:  { completion in
                print("Receive completion: ", completion)
                XCTAssert(completion == .finished)
                expectation.fulfill()
            })
        
        timerPublisher.subscribe(timerSubscriber)
        
        wait(for: [expectation], timeout: 7.0)
    }
    
    func testTimerThreadSafety() throws {
        let concurrentQueque = DispatchQueue(label: "timer_thread_safety_testing_queue",
                                             qos: .userInteractive,
                                             attributes: .concurrent)
        
        let expectationOne = XCTestExpectation(description: "Timer 1 thread safety testing")
        let expectationTwo = XCTestExpectation(description: "Timer 2 thread safety testing")
        let expectationThree = XCTestExpectation(description: "Timer 3 thread safety testing")
        
        let timerPublisherOne = Publishers.timer(queue: concurrentQueque,
                                                 interval: .nanoseconds(1),
                                                 repeatTimes: .max(6))
        let timerPublisherTwo = Publishers.timer(queue: concurrentQueque,
                                                 interval: .nanoseconds(1),
                                                 repeatTimes: .max(4))
        let timerPublisherThree = Publishers.timer(queue: concurrentQueque,
                                                   interval: .nanoseconds(1),
                                                   repeatTimes: .max(2))
        
        let timerSubscriberOne = TestableGenericSubscriber<DispatchTime, Never>.init(
            completionHook: { completion in
                print("timerSubscriberOne receive completion: ", completion)
                XCTAssert(completion == .finished)
                expectationOne.fulfill()
            })
        
        let timerSubscriberTwo = TestableGenericSubscriber<DispatchTime, Never>.init(
            completionHook: { completion in
                print("timerSubscriberTwo receive completion: ", completion)
                XCTAssert(completion == .finished)
                expectationTwo.fulfill()
            })
        
        let timerSubscriberThree = TestableGenericSubscriber<DispatchTime, Never>.init(
            completionHook: { completion in
                print("timerSubscriberThree receive completion: ", completion)
                XCTAssert(completion == .finished)
                expectationThree.fulfill()
            })
        
        
        timerPublisherOne.subscribe(timerSubscriberOne)
        timerPublisherTwo.subscribe(timerSubscriberTwo)
        timerPublisherThree.subscribe(timerSubscriberThree)
        
        wait(for: [expectationOne, expectationTwo, expectationThree], timeout: 1.0)
    }
}
