require "./spec_helper"

describe Kachet do
  it "find 1 char in prefix tree" do
    tree = Kachet::PrefixTree.new([{"A", 10}])
    tree.lookup(node_id=0, offset=0, ch='A')
      .should eq({child_id: 0, is_final: true, payload: 10})
    tree.lookup(node_id=0, offset=0, ch='B').should(eq(nil))
  end

  it "find 2 chars in prefix tree" do
    tree = Kachet::PrefixTree.new([{"AB", 20}])
    tree.lookup(node_id=0, offset=0, ch='A')
      .should(eq({child_id: 0, is_final: false, payload: nil}))
    tree.lookup(node_id=0, offset=1, ch='B')
      .should(eq({child_id: 0, is_final: true, payload: 20}))
  end

  it "find 2 words in prefix tree" do
    tree = Kachet::PrefixTree.new([{"A", 10}, {"AB", 20}])
    tree.lookup(node_id=0, offset=0, ch='A')
      .should(eq({child_id: 0, is_final: true, payload: 10}))
    tree.lookup(node_id=0, offset=1, ch='B')
      .should(eq({child_id: 1, is_final: true, payload: 20}))
  end

  it "find 2 reversed words in prefix tree" do
    tree = Kachet::PrefixTree.new([{"AB", 20}, {"A", 10}])
    tree.lookup(node_id=0, offset=0, ch='A')
      .should(eq({child_id: 0, is_final: true, payload: 10}))
    tree.lookup(node_id=0, offset=1, ch='B')
      .should(eq({child_id: 1, is_final: true, payload: 20}))
  end

  it "tokenize กากา" do
    tree = Kachet::PrefixTree.new([{"กา", true}])
    tokenizer = Kachet::Tokenizer.new(tree)
    tokenizer.tokenize("กากา")
      .should(eq(["กา", "กา"]))
  end

  it "tokenize กามกา" do
    tree = Kachet::PrefixTree.new([{"กา", true}, {"กาม", true}])
    tokenizer = Kachet::Tokenizer.new(tree)
    tokenizer.tokenize("กามกา")
      .should(eq(["กาม", "กา"]))
  end

  it "tokenize กข คง" do
    tree = Kachet::PrefixTree.new([{"กา", true}, {"กาม", true}])
    tokenizer = Kachet::Tokenizer.new(tree)
    tokenizer.tokenize("กข คง")
      .should(eq(["กข", " ", "คง"]))
  end

  it "tokenize กขABคง" do
    tree = Kachet::PrefixTree.new([{"กา", true}, {"กาม", true}])
    tokenizer = Kachet::Tokenizer.new(tree)
    tokenizer.tokenize("กขABคง")
      .should(eq(["กข", "AB", "คง"]))
  end

end
