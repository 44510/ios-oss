import Apollo
import Foundation
import ReactiveSwift

extension ApolloClient: ApolloClientType {
  /**
   Performs a GraphQL fetch request with a given query.

   - parameter query: The `Query` to fetch.

   - returns: A `SignalProducer` generic over `Query.Data` and `ErrorEnvelope`.
   */
  public func fetch<Query: GraphQLQuery>(query: Query) -> SignalProducer<Query.Data, ErrorEnvelope> {
    SignalProducer { observer, _ in
      self.fetch(query: query, cachePolicy: .fetchIgnoringCacheCompletely) { result in

        switch result {
        case let .success(response):
          if let error = response.errors?.first?.errorDescription {
            return observer.send(error: .graphError(error))
          }
          guard let data = response.data else {
            return observer.send(error: .couldNotParseJSON)
          }
//          self?.handleResponse(data: data, response: response)
//          /// `error` is `nil` or `handleError` returns `false`.
//          guard [nil, false].contains(false) else {
//            return observer.send(error: .captchaError)
//          }

          observer.send(value: data)
          observer.sendCompleted()
        case let .failure(error):
          print("🔴 [KsApi] ApolloClient query failure - error : \((error as NSError).description)")
          observer.send(error: .couldNotParseJSON)
        }
      }
    }
  }

  /**
   Performs a GraphQL mutation request with a given mutation.

   - parameter mutation: The `Mutation` to perform.

   - returns: A `SignalProducer` generic over `Mutation.Data` and `ErrorEnvelope`.
   */
  public func perform<Mutation: GraphQLMutation>(
    mutation: Mutation
  ) -> SignalProducer<Mutation.Data, ErrorEnvelope> {
    SignalProducer { observer, _ in
      self.perform(mutation: mutation) { result in
        switch result {
        case let .success(response):
          if let error = response.errors?.first?.errorDescription {
            return observer.send(error: ErrorEnvelope.graphError(error))
          }
          guard let data = response.data else {
            return observer.send(error: ErrorEnvelope.couldNotParseJSON)
          }
          
          /// `error` is `nil` or `handleError` returns `false`.
//          guard let convertedMutationData = try? JSONSerialization.data(withJSONObject: response.data?.jsonObject, options: .fragmentsAllowed), [nil, false].contains(self?.handleResponse(data: convertedMutationData, response: response.data.underlying.)) else {
//            return observer.send(error: ErrorEnvelope.captchaError)
//          }
          
          observer.send(value: data)
          observer.sendCompleted()
        case let .failure(error):
          print("🔴 [KsApi] ApolloClient mutation failure - error : \((error as NSError).description)")
          observer.send(error: .couldNotParseJSON)
        }
      }
    }
  }
}
