extension JSON 
{
    @available(*, unavailable, message: "use one of lint(discarding:_:) or lint(whitelisting:_:)")
    public 
    func lint<S, T>(_:S, _:(inout LintingDictionary) throws -> T) throws -> T
        where S:Sequence, S.Element == String
    {
        preconditionFailure()
    }

    @inlinable public 
    func lint<T>(_ body:(inout LintingDictionary) throws -> T) throws -> T
    {
        try self.lint(whitelisting: EmptyCollection<String>.init(), body)
    }
    @inlinable public 
    func lint<Discards, T>(discarding discards:Discards, 
        _ body:(inout LintingDictionary) throws -> T) throws -> T
        where Discards:Sequence, Discards.Element == String
    {
        try self.lint(whitelisting: EmptyCollection<String>.init()) 
        {
            for key:String in discards 
            {
                let _:JSON = try $0.remove(key)
            }
            return try body(&$0)
        }
    }
    @inlinable public 
    func lint<Whitelist, T>(whitelisting whitelist:Whitelist, 
        _ body:(inout LintingDictionary) throws -> T) throws -> T
        where Whitelist:Sequence, Whitelist.Element == String
    {
        var dictionary:LintingDictionary = 
            .init(try self.as([String: Self].self) { $1 })
        let result:T = try body(&dictionary)
        for key:String in whitelist
        {
            let _:JSON? = dictionary.pop(key)
        }
        guard dictionary.items.isEmpty 
        else 
        {
            throw LintingError.init(unused: dictionary.items)
        }
        return result
    }
    
    @frozen public 
    struct LintingDictionary
    {
        public 
        var items:[String: JSON]
        
        @inlinable public 
        init(_ items:[String: JSON])
        {
            self.items = items
        }
        
        /// Returns the variant value for the given key if it exists, or [`nil`]() 
        /// otherwise.
        /// 
        /// Use the ``pop(_:_:)`` method to generate a more-detailed error trace
        /// if decoding fails later.
        @inlinable public mutating 
        func pop(_ key:String) -> JSON?
        {
            self.items.removeValue(forKey: key)
        }
        /// Returns the variant value for the given key.
        /// 
        /// Use the ``remove(_:_:)`` method to generate a more-detailed error trace
        /// if decoding fails later.
        /// 
        /// >   Throws:
        ///     A ``JSON//PrimitiveError.undefined(key:in:)`` if the key does 
        ///     not exist.
        @inlinable public mutating 
        func remove(_ key:String) throws -> JSON
        {
            if let value:JSON = self.pop(key)
            {
                return value 
            }
            else 
            {
                throw PrimitiveError.undefined(key: key, in: self.items)
            }
        }
        /// Finds the variant value for the given key if it exists, and passes 
        /// it to the given closure for further decoding. Records the key being decoded if the 
        /// closure throws an error, and propogates it up the call chain.
        /// 
        /// -   Returns: The result of the closure, if the key exists and the closure succeeds,
        ///     [`nil`]() if the key does not exist.
        /// 
        /// >   Throws:
        ///     A ``JSON//RecursiveError.dictionary(underlying:in:)`` if an error 
        ///     was thrown from within the closure.
        /// 
        /// >   Note: 
        ///     A key exists even if its associated value is an explicit ``JSON/.null``.
        @inlinable public mutating 
        func pop<T>(_ key:String, _ body:(JSON) throws -> T) rethrows -> T?
        {
            guard let value:JSON = self.pop(key)
            else 
            {
                return nil
            }
            do 
            {
                #if swift(>=5.7)
                return try body(_move(value))
                #else 
                return try body(      value )
                #endif 
            }
            catch let error 
            {
                throw RecursiveError.dictionary(underlying: error, in: key)
            }
        }
        /// Finds the variant value for the given key and passes 
        /// it to the given closure for further decoding. Records the key being decoded if the 
        /// closure throws an error, and propogates it up the call chain.
        /// 
        /// -   Returns: The result of the closure, if the key exists and the closure succeeds.
        /// 
        /// >   Throws:
        ///     A ``JSON//PrimitiveError.undefined(key:in:)`` if the key does 
        ///     not exist, or a ``JSON//RecursiveError.dictionary(underlying:in:)`` 
        ///     if an error was thrown from within the given closure.
        /// 
        /// >   Note: 
        ///     A key exists even if its associated value is an explicit ``JSON/.null``.
        @inlinable public mutating 
        func remove<T>(_ key:String, _ body:(JSON) throws -> T) throws -> T
        {
            // we cannot *quite* shove this into the `do` block, because we 
            // do not want to throw a ``RecursiveError`` just because the key 
            // was not found.
            let value:JSON = try self.remove(key)
            do 
            {
                #if swift(>=5.7)
                return try body(_move(value))
                #else 
                return try body(      value )
                #endif 
            }
            catch let error 
            {
                throw RecursiveError.dictionary(underlying: error, in: key)
            }
        }
        
        // arrays 
        @inlinable public mutating 
        func pop(_ key:String, as _:[JSON].Type = [JSON].self) throws -> [JSON]?
        {
            try self.pop(key, as: [JSON].self) { $0 }
        }
        @inlinable public mutating 
        func pop(_ key:String, as _:[JSON]?.Type = [JSON]?.self) throws -> [JSON]?
        {
            try self.pop(key, as: [JSON]?.self) { $0 }
        }
        @inlinable public mutating 
        func remove(_ key:String, as _:[JSON].Type = [JSON].self) throws -> [JSON]
        {
            try self.remove(key, as: [JSON].self) { $0 }
        }
        @inlinable public mutating 
        func remove(_ key:String, as _:[JSON]?.Type = [JSON]?.self) throws -> [JSON]?
        {
            try self.remove(key, as: [JSON]?.self) { $0 }
        }
        /// Finds the variant value for the given key if it exists, attempts to unwrap it 
        /// as a variant array, and passes the array to the given closure for further decoding. 
        /// Records the key being decoded if the closure throws an error, and propogates it up the 
        /// call chain.
        /// 
        /// -   Returns: The result of the closure, if the key exists and the closure succeeds.
        /// 
        /// Calling this method is equivalent to the following:
        ///
        /// ```swift 
        /// try self.pop(key)
        /// {
        ///     try body(try $0.as([JSON].self))
        /// }
        /// ```
        /// 
        /// >   Throws:
        ///     A ``JSON//RecursiveError.dictionary(underlying:in:)`` if an error 
        ///     was thrown from within the given closure.
        /// 
        /// >   Note: 
        ///     A key exists even if its associated value is an explicit ``JSON/.null``.
        @inlinable public mutating 
        func pop<T>(_ key:String, as _:[JSON].Type, _ body:([JSON]) throws -> T) throws -> T?
        {
            try self.pop(key) { try body(try $0.as([JSON].self)) }
        }
        /// Finds the variant value for the given key, attempts to unwrap it as either a variant 
        /// array or an explicit ``JSON/.null`` value, and passes the array to the given closure for 
        /// further decoding if it is not ``JSON/.null``. Records the key being decoded if the 
        /// closure throws an error, and propogates it up the call chain.
        /// 
        /// -   Returns: The result of the closure, if the key exists and the closure succeeds, 
        ///     or [`nil`]() if the key exists but its value is an explicit ``JSON/.null``.
        /// 
        /// Calling this method is equivalent to the following:
        ///
        /// ```swift 
        /// try self.pop(key)
        /// {
        ///     try $0.as([JSON]?.self).map(body)
        /// } ?? nil
        /// ```
        /// 
        /// >   Throws:
        ///     A ``JSON//RecursiveError.dictionary(underlying:in:)`` if an error 
        ///     was thrown from within the given closure.
        @inlinable public mutating 
        func pop<T>(_ key:String, as _:[JSON]?.Type, _ body:([JSON]) throws -> T) throws -> T?
        {
            try self.pop(key) { try $0.as([JSON]?.self).map(body) } ?? nil
        }
        /// Finds the variant value for the given key, attempts to unwrap it as a variant array, 
        /// and passes the array to the given closure for further decoding. 
        /// Records the key being decoded if the closure throws an error, and propogates it up the 
        /// call chain.
        /// 
        /// -   Returns: The result of the closure, if the key exists and the closure succeeds.
        /// 
        /// Calling this method is equivalent to the following:
        ///
        /// ```swift 
        /// try self.remove(key)
        /// {
        ///     try body(try $0.as([JSON].self))
        /// }
        /// ```
        /// 
        /// >   Throws:
        ///     A ``JSON//RecursiveError.dictionary(underlying:in:)`` if an error 
        ///     was thrown from within the given closure.
        /// 
        /// >   Note: 
        ///     A key exists even if its associated value is an explicit ``JSON/.null``.
        @inlinable public mutating 
        func remove<T>(_ key:String, as _:[JSON].Type, _ body:([JSON]) throws -> T) throws -> T
        {
            try self.remove(key) { try body(try $0.as([JSON].self)) }
        }
        /// Finds the variant value for the given key, attempts to unwrap it as either a variant 
        /// array or an explicit ``JSON/.null`` value, and passes the array to the given closure for 
        /// further decoding if it is not ``JSON/.null``.
        /// Records the key being decoded if the closure throws an error, and propogates it up the 
        /// call chain.
        /// 
        /// -   Returns: The result of the closure, if the key exists and the closure succeeds, 
        ///     or [`nil`]() if the key exists but its value is an explicit ``JSON/.null``.
        /// 
        /// Calling this method is equivalent to the following:
        ///
        /// ```swift 
        /// try self.remove(key)
        /// {
        ///     try $0.as([JSON]?.self).map(body)
        /// }
        /// ```
        /// 
        /// >   Throws:
        ///     A ``JSON//RecursiveError.dictionary(underlying:in:)`` if an error 
        ///     was thrown from within the given closure.
        @inlinable public mutating 
        func remove<T>(_ key:String, as _:[JSON]?.Type, _ body:([JSON]) throws -> T) throws -> T?
        {
            try self.remove(key) { try $0.as([JSON]?.self).map(body) }
        }
        
        // null
        @inlinable public mutating 
        func remove(_ key:String, as _:Void.Type) throws 
        {
            try self.remove(key) { try $0.as(Void.self) }
        }
        @inlinable public mutating 
        func pop(_ key:String, as _:Void.Type) throws -> Void?
        {
            try self.pop(key) { try $0.as(Void.self) }
        }

        // booleans
        @inlinable public mutating 
        func remove(_ key:String, as _:Bool.Type = Bool.self) throws -> Bool
        {
            try self.remove(key) { try $0.as(Bool.self) }
        }
        @inlinable public mutating 
        func remove(_ key:String, as _:Bool?.Type = Bool?.self) throws -> Bool?
        {
            try self.remove(key) { try $0.as(Bool?.self) }
        }
        @inlinable public mutating 
        func remove<T>(_ key:String, as _:Bool.Type, _ body:(Bool) throws -> T) throws -> T
        {
            try self.remove(key) { try body(try $0.as(Bool.self)) }
        }
        @inlinable public mutating 
        func remove<T>(_ key:String, as _:Bool?.Type, _ body:(Bool) throws -> T) throws -> T?
        {
            try self.remove(key) { try $0.as(Bool?.self).map(body) }
        }

        @inlinable public mutating 
        func pop(_ key:String, as _:Bool.Type = Bool.self) throws -> Bool?
        {
            try self.pop(key) { try $0.as(Bool.self) }
        }
        @inlinable public mutating 
        func pop(_ key:String, as _:Bool?.Type = Bool?.self) throws -> Bool?
        {
            try self.pop(key) { try $0.as(Bool?.self) } ?? nil
        }
        @inlinable public mutating 
        func pop<T>(_ key:String, as _:Bool.Type, _ body:(Bool) throws -> T) throws -> T?
        {
            try self.pop(key) { try body(try $0.as(Bool.self)) }
        }
        @inlinable public mutating 
        func pop<T>(_ key:String, as _:Bool?.Type, _ body:(Bool) throws -> T) throws -> T?
        {
            try self.pop(key) { try $0.as(Bool?.self).map(body) } ?? nil
        }

        // strings
        @inlinable public mutating 
        func remove(_ key:String, as _:String.Type = String.self) throws -> String
        {
            try self.remove(key) { try $0.as(String.self) }
        }
        @inlinable public mutating 
        func remove(_ key:String, as _:String?.Type = String?.self) throws -> String?
        {
            try self.remove(key) { try $0.as(String?.self) }
        }
        @inlinable public mutating 
        func remove<T>(_ key:String, as _:String.Type, _ body:(String) throws -> T) throws -> T
        {
            try self.remove(key) { try body(try $0.as(String.self)) }
        }
        @inlinable public mutating 
        func remove<T>(_ key:String, as _:String?.Type, _ body:(String) throws -> T) throws -> T?
        {
            try self.remove(key) { try $0.as(String?.self).map(body) }
        }

        @inlinable public mutating 
        func pop(_ key:String, as _:String.Type = String.self) throws -> String?
        {
            try self.pop(key) { try $0.as(String.self) }
        }
        @inlinable public mutating 
        func pop(_ key:String, as _:String?.Type = String?.self) throws -> String?
        {
            try self.pop(key) { try $0.as(String?.self) } ?? nil
        }
        @inlinable public mutating 
        func pop<T>(_ key:String, as _:String.Type, _ body:(String) throws -> T) throws -> T?
        {
            try self.pop(key) { try body(try $0.as(String.self)) }
        }
        @inlinable public mutating 
        func pop<T>(_ key:String, as _:String?.Type, _ body:(String) throws -> T) throws -> T?
        {
            try self.pop(key) { try $0.as(String?.self).map(body) } ?? nil
        }

        // signed integers 
        @inlinable public mutating 
        func remove<Integer>(_ key:String, as _:Integer.Type = Integer.self) throws -> Integer
            where Integer:FixedWidthInteger & SignedInteger
        {
            try self.remove(key) { try $0.as(Integer.self) }
        }
        @inlinable public mutating 
        func remove<Integer>(_ key:String, as _:Integer?.Type = Integer?.self) throws -> Integer?
            where Integer:FixedWidthInteger & SignedInteger
        {
            try self.remove(key) { try $0.as(Integer?.self) }
        }
        @inlinable public mutating 
        func remove<Integer, T>(_ key:String, as _:Integer.Type, _ body:(Integer) throws -> T) throws -> T
            where Integer:FixedWidthInteger & SignedInteger
        {
            try self.remove(key) { try body(try $0.as(Integer.self)) }
        }
        @inlinable public mutating 
        func remove<Integer, T>(_ key:String, as _:Integer?.Type, _ body:(Integer) throws -> T) throws -> T?
            where Integer:FixedWidthInteger & SignedInteger
        {
            try self.remove(key) { try $0.as(Integer?.self).map(body) }
        }

        @inlinable public mutating 
        func pop<Integer>(_ key:String, as type:Integer.Type = Integer.self) throws -> Integer?
            where Integer:FixedWidthInteger & SignedInteger
        {
            try self.pop(key) { try $0.as(Integer.self) }
        }
        @inlinable public mutating 
        func pop<Integer>(_ key:String, as type:Integer?.Type = Integer?.self) throws -> Integer?
            where Integer:FixedWidthInteger & SignedInteger
        {
            try self.pop(key) { try $0.as(Integer?.self) } ?? nil
        }
        @inlinable public mutating 
        func pop<Integer, T>(_ key:String, as type:Integer.Type, _ body:(Integer) throws -> T) throws -> T?
            where Integer:FixedWidthInteger & SignedInteger
        {
            try self.pop(key) { try body(try $0.as(Integer.self)) }
        }
        @inlinable public mutating 
        func pop<Integer, T>(_ key:String, as type:Integer?.Type, _ body:(Integer) throws -> T) throws -> T?
            where Integer:FixedWidthInteger & SignedInteger
        {
            try self.pop(key) { try $0.as(Integer?.self).map(body) } ?? nil
        }

        // unsigned integers 
        @inlinable public mutating 
        func remove<Integer>(_ key:String, as _:Integer.Type = Integer.self) throws -> Integer
            where Integer:FixedWidthInteger & UnsignedInteger
        {
            try self.remove(key) { try $0.as(Integer.self) }
        }
        @inlinable public mutating 
        func remove<Integer>(_ key:String, as _:Integer?.Type = Integer?.self) throws -> Integer?
            where Integer:FixedWidthInteger & UnsignedInteger
        {
            try self.remove(key) { try $0.as(Integer?.self) }
        }
        @inlinable public mutating 
        func remove<Integer, T>(_ key:String, as _:Integer.Type, _ body:(Integer) throws -> T) throws -> T
            where Integer:FixedWidthInteger & UnsignedInteger
        {
            try self.remove(key) { try body(try $0.as(Integer.self)) }
        }
        @inlinable public mutating 
        func remove<Integer, T>(_ key:String, as _:Integer?.Type, _ body:(Integer) throws -> T) throws -> T?
            where Integer:FixedWidthInteger & UnsignedInteger
        {
            try self.remove(key) { try $0.as(Integer?.self).map(body) }
        }

        @inlinable public mutating 
        func pop<Integer>(_ key:String, as _:Integer.Type = Integer.self) throws -> Integer?
            where Integer:FixedWidthInteger & UnsignedInteger
        {
            try self.pop(key) { try $0.as(Integer.self) }
        }
        @inlinable public mutating 
        func pop<Integer>(_ key:String, as _:Integer?.Type = Integer?.self) throws -> Integer?
            where Integer:FixedWidthInteger & UnsignedInteger
        {
            try self.pop(key) { try $0.as(Integer?.self) } ?? nil
        }
        @inlinable public mutating 
        func pop<Integer, T>(_ key:String, as _:Integer.Type, _ body:(Integer) throws -> T) throws -> T?
            where Integer:FixedWidthInteger & UnsignedInteger
        {
            try self.pop(key) { try body(try $0.as(Integer.self)) }
        }
        @inlinable public mutating 
        func pop<Integer, T>(_ key:String, as _:Integer?.Type, _ body:(Integer) throws -> T) throws -> T?
            where Integer:FixedWidthInteger & UnsignedInteger
        {
            try self.pop(key) { try $0.as(Integer?.self).map(body) } ?? nil
        }

        // floating point 
        @inlinable public mutating 
        func remove<Binary>(_ key:String, as _:Binary.Type = Binary.self) throws -> Binary
            where Binary:BinaryFloatingPoint
        {
            try self.remove(key) { try $0.as(Binary.self) }
        }
        @inlinable public mutating 
        func remove<Binary>(_ key:String, as _:Binary?.Type = Binary?.self) throws -> Binary?
            where Binary:BinaryFloatingPoint
        {
            try self.remove(key) { try $0.as(Binary?.self) }
        }
        @inlinable public mutating 
        func remove<Binary, T>(_ key:String, as _:Binary.Type, _ body:(Binary) throws -> T) throws -> T
            where Binary:BinaryFloatingPoint
        {
            try self.remove(key) { try body(try $0.as(Binary.self)) }
        }
        @inlinable public mutating 
        func remove<Binary, T>(_ key:String, as _:Binary?.Type, _ body:(Binary) throws -> T) throws -> T?
            where Binary:BinaryFloatingPoint
        {
            try self.remove(key) { try $0.as(Binary?.self).map(body) }
        }

        @inlinable public mutating 
        func pop<Binary>(_ key:String, as _:Binary.Type = Binary.self) throws -> Binary?
            where Binary:BinaryFloatingPoint
        {
            try self.pop(key) { try $0.as(Binary.self) }
        }
        @inlinable public mutating 
        func pop<Binary>(_ key:String, as _:Binary?.Type = Binary?.self) throws -> Binary?
            where Binary:BinaryFloatingPoint
        {
            try self.pop(key) { try $0.as(Binary?.self) } ?? nil
        }
        @inlinable public mutating 
        func pop<Binary, T>(_ key:String, as _:Binary.Type, _ body:(Binary) throws -> T) throws -> T?
            where Binary:BinaryFloatingPoint
        {
            try self.pop(key) { try body(try $0.as(Binary.self)) }
        }
        @inlinable public mutating 
        func pop<Binary, T>(_ key:String, as _:Binary?.Type, _ body:(Binary) throws -> T) throws -> T?
            where Binary:BinaryFloatingPoint
        {
            try self.pop(key) { try $0.as(Binary?.self).map(body) } ?? nil
        }
    }
} 
