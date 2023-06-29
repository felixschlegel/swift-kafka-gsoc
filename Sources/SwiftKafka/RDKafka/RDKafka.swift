//===----------------------------------------------------------------------===//
//
// This source file is part of the swift-kafka-gsoc open source project
//
// Copyright (c) 2022 Apple Inc. and the swift-kafka-gsoc project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of swift-kafka-gsoc project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Crdkafka
import Logging

/// A collection of helper functions wrapping common `rd_kafka_*` functions in Swift.
struct RDKafka {
    /// Determines if client is a producer or a consumer.
    enum ClientType {
        case producer
        case consumer
    }

    /// Factory method creating a new instance of a ``KafkaClient``.
    static func createClient(
        type: ClientType,
        configDictionary: [String: String],
        deliveryReportCallback: RDKafkaConfig.CapturedClosures.DeliveryReportClosure? = nil,
        logger: Logger
    ) throws -> KafkaClient {
        let clientType = type == .producer ? RD_KAFKA_PRODUCER : RD_KAFKA_CONSUMER

        let rdConfig = try RDKafkaConfig.createFrom(configDictionary: configDictionary)

        // Check that delivery report callback can be only set for producer
        guard deliveryReportCallback == nil || type == .producer else {
            fatalError("Delivery report callback can't be defined for consumer client")
        }

        let opaque = RDKafkaConfig.setCallbackClosures(
            configPointer: rdConfig,
            deliveryReportCallback: deliveryReportCallback,
            logger: logger
        )

        let errorChars = UnsafeMutablePointer<CChar>.allocate(capacity: KafkaClient.stringSize)
        defer { errorChars.deallocate() }

        guard let handle = rd_kafka_new(
            clientType,
            rdConfig,
            errorChars,
            KafkaClient.stringSize
        ) else {
            // rd_kafka_new only frees the rd_kafka_conf_t upon success
            rd_kafka_conf_destroy(rdConfig)

            let errorString = String(cString: errorChars)
            throw KafkaError.client(reason: errorString)
        }

        return KafkaClient(kafkaHandle: handle, opaque: opaque, logger: logger)
    }
}
