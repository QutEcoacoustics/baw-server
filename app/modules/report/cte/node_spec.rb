# frozen_string_literal: true

describe Report::Cte::Node do
  users = User.arel_table # puts 'users' in lexical scope of `select` blocks

  describe '.new' do
    context 'with a block' do
      it 'initializes successfully' do
        node = Report::Cte::Node.new(:test_node) { users.project(users[:id]) }

        expect(node).to be_a(Report::Cte::Node)
      end
    end

    context 'with a select proc' do
      it 'initializes successfully' do
        select = -> { users.project(users[:id]) }
        node = Report::Cte::Node.new(:test_node, select: select)

        expect(node).to be_a(Report::Cte::Node)
      end
    end

    context 'without a block or select' do
      it 'raises an ArgumentError' do
        expect { Report::Cte::Node.new(:test_node) }
          .to raise_error(ArgumentError, /Either a block or select must be provided/)
      end
    end

    context 'with a non-proc select' do
      it 'raises an ArgumentError' do
        expect { Report::Cte::Node.new(:test_node, select: 'invalid') }
          .to raise_error(ArgumentError, /Select must be a Proc/)
      end
    end

    context 'with a suffix' do
      it 'appends the suffix to the name' do
        node = Report::Cte::Node.new(:test_node, suffix: :v1) { users.project(users[:id]) }

        expect(node.name).to eq(:test_node_v1)
      end
    end

    context 'with options' do
      it 'merges options with defaults' do
        node = Report::Cte::Node.new(:test_node, options: { key: 'value' }) { users.project(users[:id]) }

        expect(node.options).to eq({ key: 'value' })
      end
    end
  end

  describe '#table' do
    it 'returns a memoized Arel::Table with the node name' do
      node = Report::Cte::Node.new(:test_node) { users.project(users[:id]) }

      table = node.table

      expect(table).to be_a(Arel::Table)
      expect(table.name).to eq('test_node')
      expect(node.table).to be(table) # memoization check
    end
  end

  describe '#select_manager' do
    it "returns a memoized Arel::SelectManager representation of the node's select statement" do
      select = -> { users.project(users[:id]) }
      node = Report::Cte::Node.new(:test_node, select:)

      select_manager = node.select_manager

      expect(select_manager).to be_a(Arel::SelectManager)
      expect(select_manager.to_sql).to eq('SELECT "users"."id" FROM "users"')
      expect(node.select_manager).to be(select_manager) # memoization check
    end

    it 'wraps an Arel::Nodes::SqlLiteral in a SelectManager' do
      sql = Arel.sql('id FROM users')
      node = Report::Cte::Node.new(:test_node, select: -> { sql })

      expect(node.select_manager).to be_a(Arel::SelectManager)
      expect(node.select_manager.to_sql).to eq('SELECT id FROM users')
    end

    it 'raises an error for unsupported select types' do
      node = Report::Cte::Node.new(:test_node, select: -> { 'invalid' })
      expect { node.select_manager }.to raise_error(ArgumentError, /Unsupported select type/)
    end
  end

  describe '#node' do
    it 'returns an Arel::Nodes::As representation of the node' do
      node = Report::Cte::Node.new(:test_node) { users.project(users[:id]) }
      as_node = node.node
      expect(as_node).to be_a(Arel::Nodes::As)
      expect(as_node.left).to eq('test_node')
      expect_common(as_node.right, node.select_manager)
    end
  end

  describe '#to_arel' do
    it 'returns the select manager when no dependencies exist' do
      node = Report::Cte::Node.new(:test_node) { users.project(users[:id]) }
      arel = node.to_arel
      expect(arel).to be_a(Arel::SelectManager)
      expect(arel.to_sql).to eq('SELECT "users"."id" FROM "users"')
    end

    it 'includes dependencies in a WITH clause' do
      dep = Report::Cte::Node.new(:dep_node) { users.project(users[:id]) }
      node = Report::Cte::Node.new(:test_node, dependencies: { dep: dep }) { dep.table.project(Arel.star) }
      arel = node.to_arel
      expect(arel.to_sql.squish).to eq <<~SQL.squish
        WITH "dep_node" AS
          (SELECT "users"."id" FROM "users")
        SELECT * FROM "dep_node"
      SQL
    end
  end

  describe '#to_sql' do
    it 'generates correct SQL' do
      node = Report::Cte::Node.new(:test_node) { users.project(users[:id]) }
      expect(node.to_sql).to eq(node.to_arel.to_sql)
      expect(node.to_sql).to eq('SELECT "users"."id" FROM "users"')
    end
  end

  describe '#execute' do
    it 'executes the generated SQL' do
      debugger
      node = Report::Cte::Node.new(:test_node) { users.project(users[:id]) }
      result = node.execute.to_a.pluck('id')
      expect(result).to eq(User.pluck(:id))
    end
  end

  describe '#dependencies' do
    context 'with instance dependencies' do
      it 'returns the instances directly' do
        dep = Report::Cte::Node.new(:dep_node) { users.project(users[:id]) }
        node = Report::Cte::Node.new(:test_node, dependencies: { dep: dep }) { users.project(users[:id]) }

        expect(node.dependencies[:dep]).to eq(dep)
      end
    end

    context 'with class dependencies' do
      dep_class = Class.new(Report::Cte::Node) do
        def initialize(name = :dep_node, suffix: nil, options: {}, select: -> { users.project(users[:id]) })
          super
        end
      end

      it 'instantiates the class when called' do
        node = Report::Cte::Node.new(:test_node, dependencies: { dep: dep_class }) {
          users.project(users[:id])
        }

        dep_instance = node.dependencies[:dep]

        expect(dep_instance).to be_a(dep_class)
        expect(dep_instance.name).to eq(:dep_node)
      end

      it 'propogates suffix and options from the receiver node' do
        node = Report::Cte::Node.new(:test_node, suffix: :v1, options: { limit: 10 },
          dependencies: { dep: dep_class }) {
          users.project(users[:id])
        }

        dep_instance = node.dependencies[:dep]

        expect(dep_instance).to be_a(dep_class)
        expect(dep_instance.name).to eq(:dep_node_v1)
        expect(dep_instance.options).to eq({ limit: 10 })
      end
    end

    context 'with invalid dependencies' do
      it 'raises an ArgumentError' do
        node = Report::Cte::Node.new(:test_node, dependencies: { dep: String }) { users.project(users[:id]) }

        expect { node.dependencies }.to raise_error(ArgumentError, /Dependency must be a Node or subclass/)
      end
    end

    it 'memoizes the resolved dependencies' do
      dep = Report::Cte::Node.new(:dep_node) { users.project(users[:id]) }
      node = Report::Cte::Node.new(:test_node, dependencies: { dep: dep }) { users.project(users[:id]) }
      first_call = node.dependencies

      expect(node.dependencies).to be(first_call)
    end
  end

  describe '#collect' do
    it 'returns nodes in topological order including self' do
      dep = Report::Cte::Node.new(:dep_node) { users.project(users[:id]) }
      node = Report::Cte::Node.new(:test_node, dependencies: { dep: dep }) { dep.table.project(Arel.star) }

      expect(node.collect).to eq([dep, node])
    end

    context 'with registry injection' do
      dep_class = Class.new(Report::Cte::Node) do
        def initialize(name = :dep_node, suffix: nil, options: {}, select: -> { users.project(users[:id]) })
          super
        end
      end

      it 'uses injected nodes' do
        injected = Report::Cte::Node.new(:dep_node) { users.project(Arel.star) }
        registry = { dep_node: injected }
        node = Report::Cte::Node.new(:test_node, dependencies: { dep: dep_class }) { users.project(users[:id]) }

        expect(node.collect(registry)).to eq([injected, node])
      end
    end
  end

  describe 'select statement execution context' do
    it 'gives access to node options' do
      node = Report::Cte::Node.new(:test_node, options: { limit: 10 }) {
        users.project(users[:id]).take(options[:limit])
      }

      expect(node.select_manager.to_sql).to eq('SELECT "users"."id" FROM "users" LIMIT 10')
    end

    it 'gives access to Arel::Tables of node dependencies' do
      dep = Report::Cte::Node.new(:dep_node) { users.project(users[:id]) }
      dep_hash = { some_cte: dep }

      node = Report::Cte::Node.new(:test_node, dependencies: dep_hash) {
        some_cte.project(some_cte[:id])
      }

      expect(node.select_manager.to_sql).to eq('SELECT "dep_node"."id" FROM "dep_node"')
    end
  end
end
