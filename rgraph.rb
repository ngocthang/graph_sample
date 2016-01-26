require 'json'
require 'rest_client'

class RGraph

  def initialize
    @url = 'http://localhost:7474/db/data/cypher'
    @data = {
        nodes: [
            {
                label: 'Person',
                title: 'Territory Manager',
                name: 'Linda Barnes'
            },
            {
                label: 'Person',
                title: 'Account Manager',
                name: 'Jeff Dudley',
            },
            # ...
            {
                label: 'Company',
                name: 'OurCompany, Inc.'
            },
            {
                label: 'Company',
                name: 'Acme, Inc.'
            },
            {
                label: 'Company',
                name: 'Wiley, Inc.'
            },
            {
                label: 'Company',
                name: 'Coyote, Ltd.'
            },
        ],
        relationships: [
            {
                type: 'MANAGES',
                source: 'Linda Barnes',
                destination: ['Jeff Dudley', 'Mike Wells', 'Vanessa Jones']
            },
            {
                type: 'MANAGES',
                source: 'Jesse Hoover',
                destination: ['Ralph Green', 'Patricia McDonald']
            },
            # ...
            {
                type: 'WORKS_FOR',
                destination: 'OurCompany, Inc.',
                source: ['Linda Barnes', 'Jeff Dudley', 'Mike Wells', 'Vanessa Jones']
            },
            {
                type: 'WORKS_FOR',
                destination: 'Acme, Inc.',
                source: ['Jesse Hoover', 'Ralph Green', 'Sheila Foxworthy', 'Janet Huxley-Smith',
                         'Tim Reynolds', 'Zachary Meyer', 'Milton Stacey', 'Steve Nauman', 'Patricia McDonald']
            },
            # ...
            {
                type: 'ACCOUNT_MANAGES',
                source: 'Jeff Dudley',
                destination: 'Acme, Inc.'
            },
            {
                type: 'ACCOUNT_MANAGES',
                source: 'Mike Wells',
                destination: 'Wiley, Inc.'
            },
            {
                type: 'ACCOUNT_MANAGES',
                source: 'Vanessa Jones',
                destination: 'Coyote, Ltd.'
            },
            {
                type: 'HAS_MET_WITH',
                source: 'Jeff Dudley',
                destination: ['Tim Reynolds', 'Zachary Meyer', 'Janet Huxley-Smith', 'Patricia McDonald']
            },
            {
                type: 'HAS_MET_WITH',
                source: 'Mike Wells',
                destination: ['Francine Gonzalez', 'Tsunomi Ito', 'Frank Cutler']
            },
            {
                type: 'HAS_MET_WITH',
                source: 'Vanessa Jones',
                destination: 'Tracey Stankowski'
            }
        ]
      }
  end
  
  def create_node(label,attr={})
    query = ''  # khai báo biến query dạng string
    attributes = '' # biến lưu tên các attribute
    if attr.size == 0
      # nếu ko có attribute thì sẽ khởi tạo 1 node
      query += "CREATE (:#{label});"
    else
      # Create the attribute clause portion of the query
      attributes += '{ '
      attr.each do |key,value|
        attributes += "#{key.to_s}: '#{value}',"
      end
      attributes.chomp!(',') # xoá dấu phẩy cuối
      attributes += ' }'
      query += "CREATE (:#{label} " + attributes + ');'
    end
    c = {
        "query" => "#{query}",
        "params" => {}
    }
    RestClient.post @url, c.to_json, :content_type => :json, :accept => :json
  end
  
  def create_directed_relationship (from_node, to_node, rel_type)
    query = ''  
    attributes = '' 
    query += "MATCH ( a:#{from_node[:type]} "
    from_node.each do |key,value|
      next if key == :type # nếu attribute là `type` thì bỏ qua
      attributes += "#{key.to_s}: '#{value}',"
    end
    attributes.chomp!(',') # bỏ dấu phẩy cuối
    query += "{ #{attributes} }),"
    attributes = '' # Reset attribut để thực hiện câu lệnh match tiếp theo
    query += " ( b:#{to_node[:type]} "
    to_node.each do |key,value|
      next if key == :type 
      attributes += "#{key.to_s}: '#{value}',"
    end
    attributes.chomp!(',')
    query += "{ #{attributes} }) "
    # node a và node b đã được khai báo , giờ ta sẽ thưc hiện nối chúng lại
    query += "CREATE (a)-[:#{rel_type}]->(b);"
    c = {
        "query" => "#{query}",
        "params" => {}
    }
    RestClient.post @url, c.to_json, :content_type => :json, :accept => :json
  end
  
  def create_nodes
    # Scan file, find each node and create it in Neo4j
    @data.each do |key,value|
      if key == :nodes
        @data[key].each do |node| # lặp các key trong @data
          next unless node.has_key?(:label) # bỏ qua các node ko có label
          label = node[:label]
          attr = Hash.new
          node.each do |k,v| 
            next if k == :label # ta sẽ ko tạo attribute khi key = "label"
            attr[k] = v
          end
          create_node(label,attr)
        end
      end
    end
  end
  
  def create_directed_relationships
    # Scan file, look for relationships and their respective nodes
    @data.each do |key,value|
      if key == :relationships
        @data[key].each do |relationship| # Cycle through each relationship
          next unless relationship.has_key?(:type) &&
              relationship.has_key?(:source) &&
              relationship.has_key?(:destination)
          rel_type = relationship[:type]
          case rel_type
            # Handle the different types of cases
            when 'MANAGES', 'ACCOUNT_MANAGES', 'HAS_MET_WITH'
              # in all cases, we have one :Person source and one or more destinations
              from_node = {type: 'Person', name: relationship[:source]}
              to_node = (rel_type == 'ACCOUNT_MANAGES') ? {type: 'Company'} : {type: 'Person'}
              if relationship[:destination].class == Array
                # multiple destinations
                relationship[:destination].each do |dest|
                  to_node[:name] = dest
                  create_directed_relationship(from_node,to_node,rel_type)
                end
              else
                to_node[:name] = relationship[:destination]
                create_directed_relationship(from_node,to_node,rel_type)
              end
            when 'WORKS_FOR'
              # one destination, one or more sources
              to_node = {type: 'Company', name: relationship[:destination]}
              from_node = {type: 'Person'}
              rel_type = 'WORKS_FOR'
              if relationship[:source].class == Array
                # multiple sources
                relationship[:source].each do |src|
                  from_node[:name] = src
                  create_directed_relationship(from_node,to_node,rel_type)
                end
              else
                from_node[:name] = relationship[:source]
              end
          end
        end
      end
    end
  end
end

rGraph = RGraph.new
rGraph.create_nodes
rGraph.create_directed_relationships