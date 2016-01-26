require 'rubygems'
require 'bundler/setup'
require 'neo4j'
require 'pry'

Neo4j::Session.open(:server_db, "http://localhost:7474")

Neo4j::Transaction.run do
  binding.pry
  me  = Neo4j::Node.new :name => 'Me',   :age => 31
  # bob  = Neo4j::Node.new(:name => 'Bob',  :age => 29)
  # mark = Neo4j::Node.new(:name => 'Mark', :age => 34)
  # mary = Neo4j::Node.new(:name => 'Mary', :age => 32)
  # john = Neo4j::Node.new(:name => 'John', :age => 33)
  # andy = Neo4j::Node.new(:name => 'Andy', :age => 31)

  me.both(:friends)   << bob
  bob.both(:friends)  << mark
  mark.both(:friends) << mary
  mary.both(:friends) << john
  john.both(:friends) << andy 
end

#puts me.outgoing(:friends).depth(5).map{|node| node[:name]}.join(" => ")
