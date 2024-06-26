import Foundation

extension DispatchTimeInterval {
  public func scale(by scale: Float) -> DispatchTimeInterval {
    #if swift(>=3.2)
      switch self {
      case let .seconds(interval):
        return .milliseconds(Int(Float(interval * 1_000) * scale))
      case let .milliseconds(interval):
        return .microseconds(Int(Float(interval * 1_000) * scale))
      case let .microseconds(interval):
        return .nanoseconds(Int(Float(interval * 1_000) * scale))
      case let .nanoseconds(interval):
        return .nanoseconds(Int(Float(interval) * scale))
      case .never:
        return .never
      @unknown default:
        fatalError()
      }
    #else
      switch self {
      case let .seconds(interval):
        return .milliseconds(Int(Float(interval * 1_000) * scale))
      case let .milliseconds(interval):
        return .microseconds(Int(Float(interval * 1_000) * scale))
      case let .microseconds(interval):
        return .nanoseconds(Int(Float(interval * 1_000) * scale))
      case let .nanoseconds(interval):
        return .nanoseconds(Int(Float(interval) * scale))
      }
    #endif
  }

  public func halved() -> DispatchTimeInterval {
    return self.scale(by: 0.5)
  }

  private var nanoseconds: Int64 {
    #if swift(>=3.2)
      switch self {
      case let .seconds(s):
        return Int64(s) * Int64(NSEC_PER_SEC)
      case let .milliseconds(ms):
        return Int64(ms) * Int64(NSEC_PER_MSEC)
      case let .microseconds(us):
        return Int64(us) * Int64(NSEC_PER_USEC)
      case let .nanoseconds(ns):
        return Int64(ns)
      case .never:
        return Int64(0)
      @unknown default:
        fatalError()
      }
    #else
      switch self {
      case let .seconds(s):
        return Int64(s) * Int64(NSEC_PER_SEC)
      case let .milliseconds(ms):
        return Int64(ms) * Int64(NSEC_PER_MSEC)
      case let .microseconds(us):
        return Int64(us) * Int64(NSEC_PER_USEC)
      case let .nanoseconds(ns):
        return Int64(ns)
      }
    #endif
  }

  public static func + (lhs: DispatchTimeInterval, rhs: DispatchTimeInterval) -> DispatchTimeInterval {
    return .nanoseconds(Int(lhs.nanoseconds + rhs.nanoseconds))
  }
}
