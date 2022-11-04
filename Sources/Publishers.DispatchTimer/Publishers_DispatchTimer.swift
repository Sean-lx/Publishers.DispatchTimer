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
    var timerSource: DispatchSourceTimer? = nil
    var subscriber: S?
    let semaphore = DispatchSemaphore(value: 0)
    
    init(subscriber: S, configuration: DispatchTimerConfiguration) {
        self.configuration = configuration
        self.subscriber = subscriber
        self.maximumCount = configuration.repetitionCount
    }
    
    func initTimerSource() -> DispatchSourceTimer {
        let defaultQueue = DispatchQueue.init(label: "dispatch_timer_dafault_queue",
                                              qos: .background,
                                              attributes: .concurrent)
        let sourceQueue = configuration.queue ?? defaultQueue
        // makeTimerSource(:) takes a dispatch queue which the event handler will be
        // running on, the default queue is a background queue if we pass nil to
        // the parameter.
        // It is better to explicitly make the default queue a background queue,
        // because we don't know whether Apple will change this default value in the
        // future.
        let timerSource = DispatchSource.makeTimerSource(queue: sourceQueue)
        timerSource.schedule(deadline: .now() + configuration.interval,
                             repeating: configuration.interval,
                             leeway: configuration.leeway)
        return timerSource
    }
    
    func initTimerEventHandler() -> DispatchWorkItem {
        let qos = configuration.queue?.qos ?? .default
        let handler = DispatchWorkItem.init {
            // self.timerSource?.cancel() is asynchronous, it is not thread safe,
            // even the whole event block is installed on a serial queue.
            // One way to keep this handler thread safe is to use semaphore to sychronize
            // the asynchronous cancel call.
            // Another way is using DispatchQueue.sync to wrap up this handler.
            DispatchQueue.global(qos: qos.qosClass).async { [weak self] in
                guard let self = self,
                      self.requestedCount > .none else { return }
                
                self.requestedCount -= .max(1)
                self.maximumCount -= .max(1)
                // receive value and update demand
                self.requestedCount += self.subscriber?.receive(.now()) ?? .none
                
                if self.maximumCount == .none || self.requestedCount == .none {
                    self.subscriber?.receive(completion: .finished)
                    self.timerSource?.cancel()
                }
                self.semaphore.signal()
            }
            self.semaphore.wait()
        }
        return handler
    }
    
    func activate(timerSource: DispatchSourceTimer, with eventHandler: DispatchWorkItem) {
        timerSource.setEventHandler(handler: eventHandler)
        timerSource.activate()
    }
    
    func activateTimerSource() {
        if timerSource == nil, requestedCount > .none {
            timerSource = initTimerSource()
            let eventHandler = initTimerEventHandler()
            activate(timerSource: timerSource!, with: eventHandler)
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
        timerSource?.cancel()
        timerSource = nil
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



