// MARK: - Random Number Generation

import Foundation

/// Protocol for random number generation.
/// Abstracted to allow deterministic testing with seeded generators.
public protocol RandomNumberGenerator: Swift.RandomNumberGenerator {
    mutating func next() -> UInt64
}

/// Default implementation using system RNG.
public struct SystemRNG: RandomNumberGenerator, @unchecked Sendable {
    private var inner = Swift.SystemRandomNumberGenerator()
    
    public init() {}
    
    public mutating func next() -> UInt64 {
        return inner.next()
    }
}

/// Deterministic RNG for testing and replay.
/// Uses a linear congruential generator for reproducibility.
public struct SeededRNG: RandomNumberGenerator, Sendable {
    private var state: UInt64
    
    public init(seed: UInt64) {
        self.state = seed
    }
    
    public mutating func next() -> UInt64 {
        // LCG parameters (same as glibc)
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

// MARK: - Dice Rolling

/// Result of rolling two dice.
public struct DiceRoll: Sendable, Equatable, Hashable, Codable {
    public let die1: Int
    public let die2: Int
    public var total: Int { die1 + die2 }
    
    public init(die1: Int, die2: Int) {
        self.die1 = die1
        self.die2 = die2
    }
    
    /// Roll two dice using the provided RNG.
    public static func roll<R: RandomNumberGenerator>(using rng: inout R) -> DiceRoll {
        let die1 = Int.random(in: 1...6, using: &rng)
        let die2 = Int.random(in: 1...6, using: &rng)
        return DiceRoll(die1: die1, die2: die2)
    }
}

// MARK: - Shuffle Extension

extension Array {
    /// Shuffle array using the provided RNG.
    public mutating func shuffle<R: RandomNumberGenerator>(using rng: inout R) {
        for i in stride(from: count - 1, through: 1, by: -1) {
            let j = Int.random(in: 0...i, using: &rng)
            swapAt(i, j)
        }
    }
    
    /// Return shuffled copy using the provided RNG.
    public func shuffled<R: RandomNumberGenerator>(using rng: inout R) -> [Element] {
        var copy = self
        copy.shuffle(using: &rng)
        return copy
    }
}

