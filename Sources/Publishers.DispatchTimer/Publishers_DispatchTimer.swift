import Foundation
import Combine

@available(macOS 10.15, iOS 13.0, watchOS 6.0, *)
struct DispatchTimerConfiguration {
    let queue: DispatchQueue?
    let interval: DispatchTimeInterval
    let leeway: DispatchTimeInterval
    let repetitionCount: Subscribers.Demand
}

@available(macOS 10.15, iOS 13.0, watchOS 6.0, *)
extension Publishers {
    struct DispatchTimer: Publisher {
        typealias Output = DispatchTime
        typealias Failure = Never
        
        let configuration: DispatchTimerConfiguration
        
        init(configuration: DispatchTimerConfiguration) {
            self.configuration = configuration
        }
        
        func receive<S: Subscriber>(subscriber: S)
        where Failure == S.Failure,
              Output == S.Input {
                  let subscription = DispatchTimerSubscription(
                    subscriber: subscriber,
                    configuration: configuration
                  )
                  subscriber.receive(subscription: subscription)
              }
    }
}

@available(macOS 10.15, iOS 13.0, watchOS 6.0, *)
private final class DispatchTimerSubscription<S: Subscriber>: Subscription
where S.Input == DispatchTime {
    let configuration: DispatchTimerConfiguration
    var maximumCount: Subscribers.Demand             // the repeat times of timer.
    var requestedCount: Subscribers.Demand = .none   // the item count demanded by subscriber
    var source: DispatchSourceTimer? = nil
    var subscriber: S?
    let semaphore = DispatchSemaphore(value: 1)
    
    init(subscriber: S,
         configuration: DispatchTimerConfiguration) {
        self.configuration = configuration
        self.subscriber = subscriber
        self.maximumCount = configuration.repetitionCount
    }
    
    func initTimerSource() -> DispatchSourceTimer {
        let timerSource = DispatchSource.makeTimerSource(queue: configuration.queue)
        timerSource.schedule(deadline: .now() + configuration.interval,
                        repeating: configuration.interval,
                        leeway: configuration.leeway)
        return timerSource
    }
    
    func activate(timerSource: DispatchSourceTimer, eventHandler: DispatchWorkItem) {
        timerSource.setEventHandler(handler: eventHandler)
        timerSource.activate()
    }
    
    func activateTimerSource() {
        if source == nil, requestedCount > .none {
            source = initTimerSource()
            let qos = configuration.queue?.qos ?? .default
            let handler = DispatchWorkItem.init() {
                DispatchQueue.global(qos: qos.qosClass).async { [weak self] in
                    guard let self = self,
                          self.requestedCount > .none else { return }
                    
                    self.semaphore.wait()
                    self.requestedCount -= .max(1)
                    self.maximumCount -= .max(1)
                    // receive current time and update demand
                    self.requestedCount += self.subscriber?.receive(.now()) ?? .none
                    self.semaphore.signal()
                    
                    if self.maximumCount == .none || self.requestedCount == .none {
                        self.subscriber?.receive(completion: .finished)
                    }
                }
            }
            activate(timerSource: source!, eventHandler: handler)
        }
    }
    
    /// This function is called when subscribers receive subscription
    /// through receive(subscription:)
    /// - Parameter demand: the item count the subscribers want to receive
    func request(_ demand: Subscribers.Demand) {
        // if the repetition count is 0
        // publisher just emit 1 output(event): .finished
        guard maximumCount > .none else {
            subscriber?.receive(completion: .finished)
            return
        }
        
        requestedCount = demand
        
        activateTimerSource()
    }
    
    func cancel() {
        source?.cancel()
        source = nil
        subscriber = nil
    }
}

@available(macOS 10.15, iOS 13.0, watchOS 6.0, *)
public extension Publishers {
    static func timer(queue: DispatchQueue? = nil,
                      interval: DispatchTimeInterval,
                      leeway: DispatchTimeInterval = .nanoseconds(0),
                      repeatTimes: Subscribers.Demand = .unlimited)
    -> AnyPublisher<DispatchTime, Never> {
        let publisher = Publishers.DispatchTimer(
            configuration: .init(queue: queue,
                                 interval: interval,
                                 leeway: leeway,
                                 repetitionCount: repeatTimes))
        return publisher.eraseToAnyPublisher()
    }
}



