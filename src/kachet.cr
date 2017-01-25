require "./kachet/*"

module Kachet

  alias Edge = NamedTuple(p: Int32, edge_type: EdgeType, 
                          w: Int32, unk: Int32)
 
  class Pointer
    property s, node_id, offset, is_final

    def initialize(@s : Int32, 
                   @node_id : Int32, 
                   @offset : Int32,
                   @is_final : Bool)
    end
  end

  struct Context
    property ch, i, left_boundary, best_edge, path, text

    def initialize(@ch : Char, 
                   @i : Int32,
                   @left_boundary : Int32,
                   @best_edge : Edge|Nil,
                   @path : Array(Edge),
                   @text : Array(Char))
    end
  end  

  enum EdgeType
    Init
    Dict 
    Unk
    Latin
    Punc
  end

  def self.is_better_than(e0, e1)
    return true if e0[:unk] < e1[:unk]
    return false if e0[:unk] > e1[:unk]
    return true if e0[:w] < e1[:w]
    return false if e0[:w] > e1[:w]
    return true if e0[:edge_type] != EdgeType::Unk && e1[:edge_type] == EdgeType::Unk
    return false
  end

  class EdgeBuilder
    def build(context : Context) : Edge|Nil
    end
  end

  class DictEdgeBuilder < EdgeBuilder
    def initialize(tree : PrefixTree(Bool))
      @tree = tree
      @n = 0
      @pointers = Array(Pointer).new(0xF, Pointer.new(0,0,0,false))
    end

    def resize()
      if @n == @pointers.size
        @pointers << Pointer.new(0,0,0,false)
      end
    end    

    def update(pointer, ch)
      child = @tree.lookup(pointer.node_id, pointer.offset, ch)
      if child
        pointer.node_id = child[:child_id]
        pointer.offset += 1
        pointer.is_final = child[:is_final]
        return true
      else
        return false
      end
    end

    def build(context : Context) : Edge|Nil
      resize
      @pointers[@n] = Pointer.new(context.i, 0, 0, false)
      @n += 1

      j = 0
      best_edge = nil

      (0...@n).each do |i| 
        if update(@pointers[i], context.ch)
          if j < i
            @pointers[j] = @pointers[i]
          end
          pointer = @pointers[j]
          if pointer.is_final
            p = pointer.s
            source = context.path[p]
            edge = {p: p,
                    edge_type: EdgeType::Dict,
                    w: source[:w] + 1,
                    unk: source[:unk]}

            if best_edge.nil? || Kachet.is_better_than(edge, best_edge)
              best_edge = edge
            end
            
          end
          j += 1
        end
      end
      @n = j
      
      return best_edge
    end
  end

  class UnkDictEdgeBuilder < EdgeBuilder
    def build(context : Context) : Edge|Nil
      return nil if context.best_edge
      p = context.left_boundary
      source = context.path[p]
      {p: p, edge_type: EdgeType::Unk, w: source[:w] + 1, unk: source[:unk] + 1}
    end
  end

  abstract class PatEdgeBuilder < EdgeBuilder
    
    @s : Int32|Nil
    @e : Int32|Nil

    def initialize(edge_type : EdgeType)
      @edge_type = edge_type
      @s = nil
      @e = nil
    end

    def build(context : Context) : Edge|Nil
      @s = context.i if @s.nil? && check_ch(context.ch)
      
      if @s
        if check_ch(context.ch)
          @e = context.i if context.text.size == context.i + 1 || \
            !check_ch(context.text[context.i + 1])
        else
          @s = nil
          @e = nil
        end
      end

      if @s && @e
        source = context.path[@s.as(Int32)]
        {p: @s.as(Int32), 
         edge_type: @edge_type, 
         w: source[:w] + 1, 
         unk: source[:unk]}
      else
        nil  
      end
    end
    
  end

  class PuncEdgeBuilder < PatEdgeBuilder
    def initialize
      super(EdgeType::Punc)
    end

    def check_ch(ch)
      ch == ' '
    end
  end

  class LatinEdgeBuilder < PatEdgeBuilder
    def initialize
      super(EdgeType::Latin)
    end

    def check_ch(ch)
      (ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z')
    end
  end

  class Tokenizer
    @factories: Array(Proc(EdgeBuilder))

    def initialize(tree)
      @factories = [->() { DictEdgeBuilder.new(tree).as(EdgeBuilder) },
                    ->() { PuncEdgeBuilder.new().as(EdgeBuilder) },
                    ->() { LatinEdgeBuilder.new().as(EdgeBuilder) },
                    ->() { UnkDictEdgeBuilder.new().as(EdgeBuilder) }]
    end
    
    def tokenize(text : String)
      edge_builders = @factories.map{|factory| factory.call()}
      path = build_path(text, edge_builders)
      ranges = path_to_ranges(path)
      return ranges_to_tokens(ranges, text)
    end

    def path_to_ranges(path)
      e = path.size - 1
      ranges = Array(NamedTuple(s: Int32,e: Int32)).new
      while e > 0
        s = path[e][:p]
        ranges << {s: s, e: e}
        e = s
      end
      return ranges.reverse
    end

    def ranges_to_tokens(ranges, text)
      ranges.map{|r| text[r[:s]...r[:e]]}
    end

    def build_path(text, edge_builders)
      text_arr = text.chars

      context = Context.new('\0', 0, 0, nil,
        Array(Edge).new(text_arr.size + 1), text_arr)
      
      context.path << {p: 0, edge_type: EdgeType::Init, w: 0, unk: 0}      
      text_arr.each.with_index do |ch, i|
        context.i = i
        context.ch = ch
        context.best_edge = nil
        edge_builders.each do |builder|
          edge = builder.build(context)
          if edge
            context.best_edge = edge if context.best_edge.nil? || \
              Kachet.is_better_than(edge.as(Edge), context.best_edge.as(Edge))
          end
        end

        raise "Best edge cannot be nil here" if context.best_edge.nil?
        context.left_boundary = i + 1 \
           if context.best_edge.as(Edge)[:edge_type] != EdgeType::Unk
        context.path << context.best_edge.as(Edge)
      end

      return context.path
    end

  end

  def self.load_dict(path)
    words_with_payload = [] of {String,Bool}
    File.open(path).each_line do |line|
      words_with_payload << {line, true}
    end
    return PrefixTree.new(words_with_payload)
  end
end
