module Crowdring
  class TagFilter
    include DataMapper::Resource

    property :id, Serial

    has n, :tags, through: Resource

    def filter(items)
      items.select do |item|
        accept? item
      end
    end

    def tags=(tags)
      if tags.is_a? String
        tags = tags.split('|').reject(&:empty?).map {|str| Tag.from_str(str)}
      end
      super tags
    end

    def accept?(item)
      grouped_tags.reduce(true) {|acc, tags| acc and has_any?(tags, item.tags)}
    end

    private

    def grouped_tags
      tags.reduce(Hash.new {|h,k| h[k] = []}) {|hash, tag| hash[tag.type] << tag; hash}.values
    end

    def has_any?(possible_tags, item_tags)
      not (possible_tags & item_tags).empty?
    end
  end
end