class Kronk::Path::Transaction

  def initialize data, &block
    @data    = data
    @actions = Hash.new{|h,k| h[k] = []}

    @make_array = []

    run(&block) if block_given?
  end


  def run &block
    clear
    yield self
    results
  end


  def results
    new_data = transaction_select @data, *@actions[:select]
    new_data = transaction_delete new_data, *@actions[:delete]
    remake_arrays new_data
  end


  def remake_arrays new_data
    @make_array.each do |(data, path_arr, i)|
      key = path_arr[i]
      next unless Hash === data[key]
      data[key] = hash_to_ary data[key]
    end

    new_data = hash_to_ary new_data if Array === @data && Hash === new_data
    new_data
  end


  def transaction_select data, *data_paths
    return data if data_paths.empty?

    new_data = Hash.new

    [*data_paths].each do |data_path|
      Kronk::Path.find data_path, data do |obj, k, path|

        curr_data     = data
        new_curr_data = new_data

        path.each_with_index do |key, i|
          if i == path.length - 1
            new_curr_data[key] = curr_data[key]

          else
            new_curr_data[key] ||= Hash.new

            # Tag data item for conversion to Array.
            # Hashes are used to conserve position of Array elements.
            if Array === curr_data[key]
              @make_array << [new_curr_data, path, i]
            end

            new_curr_data = new_curr_data[key]
            curr_data     = curr_data[key]
          end
        end
      end
    end

    new_data
  end


  def transaction_delete data, *data_paths
    return data if data_paths.empty?

    new_data = Hash.new

    [*data_paths].each do |data_path|
      Kronk::Path.find data_path, data do |obj, k, path|

        curr_data     = data
        new_curr_data = new_data

        path.each_with_index do |key, i|
          if i == path.length - 1
            new_curr_data.delete key

          else
            if i == path.length - 2 &&
                !@make_array.include?([new_curr_data, path, i])
              new_curr_data[key] = curr_data[key].dup
            else
              new_curr_data[key] = curr_data[key]
            end

            if Array === new_curr_data[key]
              new_curr_data[key] = ary_to_hash new_curr_data[key]
              @make_array << [new_curr_data, path, i]
            end

            new_curr_data = new_curr_data[key]
            curr_data     = curr_data[key]
          end
        end
      end
    end

    new_data
  end


  def ary_to_hash ary
    hash = {}
    ary.each_with_index{|val, i| hash[i] = val}
    hash
  end


  def hash_to_ary hash
    hash.keys.sort.map{|k| hash[k] }
  end


  def clear
    @actions.clear
    @make_array.clear
  end


  def select *paths
    @actions[:select].concat paths
  end


  def delete *paths
    @actions[:delete].concat paths
  end
end