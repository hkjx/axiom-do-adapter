# encoding: utf-8

module Veritas

  # A relation backed by an adapter
  class RelationGateway
    include Enumerable, Immutable

    # remove methods so they can be proxied
    undef_method :drop, :extend, :sort_by, :take

    DECORATED_CLASS = Relation

    # The adapter the gateway will use to fetch results
    #
    # @return [Adapter::DataObjects]
    #
    # @api private
    attr_reader :adapter
    protected :adapter

    # The relation the gateway will use to generate SQL
    #
    # @return [Relation]
    #
    # @api private
    attr_reader :relation
    protected :relation

    # Initialize a RelationGateway
    #
    # @param [Adapter::DataObjects] adapter
    #
    # @param [Relation] relation
    #
    # @return [undefined]
    #
    # @api private
    def initialize(adapter, relation)
      @adapter  = adapter
      @relation = relation
    end

    # Iterate over each row in the results
    #
    # @example
    #   gateway = RelationGateway.new(adapter, relation)
    #   gateway.each { |tuple| ... }
    #
    # @yield [tuple]
    #
    # @yieldparam [Tuple] tuple
    #   each tuple in the results
    #
    # @return [self]
    #
    # @api public
    def each
      return to_enum unless block_given?
      return super if materialized?
      each_tuple { |tuple| yield tuple }
      self
    end

    # Return a relation with each tuple materialized
    #
    # @example
    #   materialized = gateway.materialize
    #
    # @return [Relation::Materialized]
    #
    # @api public
    def materialize
      Relation::Materialized.new(header, to_a, directions)
    end

    # Return a relation that is the join of two relations
    #
    # @example natural join
    #   join = relation.join(other)
    #
    # @param [Relation] other
    #   the other relation to join
    #
    # @return [RelationGateway]
    #   return a gateway if the adapters are equal
    # @return [Algebra::Join]
    #   return a normal join when the adapters are not equal
    #
    # @api public
    def join(other)
      if other.respond_to?(:adapter) && adapter.eql?(other.adapter)
        method_missing(__method__, other.relation)
      else
        Algebra::Join.new(self, other)
      end
    end

    # Test if the method is supported on this object
    #
    # @param [Symbol] method
    #
    # @return [Boolean]
    #
    # @api private
    def respond_to?(method, *)
      super || forwardable?(method)
    end

  private

    # Proxy the message to the relation
    #
    # @param [Symbol] method
    #
    # @param [Array] *args
    #
    # @return [self]
    #   return self for all command methods
    # @return [Object]
    #   return response from all query methods
    #
    # @api private
    def method_missing(method, *args, &block)
      forwardable?(method) ? forward(method, *args, &block) : super
    end

    # Test if the method can be forwarded to the relation
    #
    # @param [Symbol] method
    #
    # @return [Boolean]
    #
    # @api private
    def forwardable?(method)
      relation.respond_to?(method)
    end

    # Forward the message to the relation
    #
    # @param [Array] *args
    #
    # @return [self]
    #   return self for all command methods
    # @return [Object]
    #   return response from all query methods
    #
    # @api private
    def forward(*args, &block)
      relation = self.relation
      response = relation.public_send(*args, &block)
      if response.equal?(relation)
        self
      elsif response.kind_of?(DECORATED_CLASS)
        self.class.new(adapter, response)
      else
        response
      end
    end

    # Yield each tuple in the result
    #
    # @yield [tuple]
    #
    # @yieldparam [Tuple] tuple
    #   each tuple in the results
    #
    # @return [undefined]
    #
    # @api private
    def each_tuple
      DECORATED_CLASS.new(header, adapter.read(relation)).each do |tuple|
        yield tuple
      end
    end

  end # class RelationGateway
end # module Veritas
