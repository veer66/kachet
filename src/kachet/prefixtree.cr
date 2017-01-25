module Kachet  
  class PrefixTree(T)

    def initialize(words_with_payload : Array(Tuple(String,T)))        
        @tab = Hash(NamedTuple(node_id: Int32, offset: Int32, ch: Char),
                    NamedTuple(child_id: Int32, is_final: Bool, payload: T | Nil)).new
        words_with_payload.sort{|a,b| a[0] <=> b[0]}
                .each.with_index do |(word,payload), i|
            row_no = 0
            word_array = word.chars
            word_len = word_array.size
            word_array.each.with_index do |ch, j|
                key = {node_id: row_no, offset: j, ch: ch}
                if @tab.has_key?(key)
                     child = @tab[key]
                     row_no = child[:child_id]
                else
                     is_final = word_len == j + 1
                     @tab[key] = {child_id: i, 
                                  is_final: is_final, 
                                  payload: if is_final; payload; end}
                     row_no = i
                end
            end
        end
    end
    
    def lookup(node_id, offset, ch) : NamedTuple(child_id: Int32, is_final: Bool, payload: T | Nil)|Nil
        @tab.fetch({node_id: node_id, offset: offset, ch: ch}, nil)
    end
  end
end