# Copyright 2018 Google Inc
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.

require 'linked-list'

# A linked list node that tracks its order reltaive to other nodes.
#
# This assumes that, while nodes may be added or removed from a given list, a
# given node object will only ever have one position in the list. This invariant
# is maintained by all methods of LinkedList::List other than
# LinkedList::List#reverse and LinkedList::List#reverse!.
#
# We use this to efficiently determine where to insert a new file relative to
# existing files with HRX#write.
class HRX::OrderedNode < LinkedList::Node # :nodoc:
  def initialize(data)
    super
    @order = nil
  end

  # The relative order of this node.
  #
  # This is guaranteed to be greater than the order of all nodes before this in
  # the list, and less than the order of all nodes after it. Otherwise it
  # provides no guarantees.
  #
  # This is not guaranteed to be stale over time.
  def order
    @order || 0
  end

  def next=(other)
    @order ||=
      if other.nil?
        nil
      elsif other.prev
        (other.prev.order + other.order) / 2.0
      else
        other.order - 1
      end
    super
  end

  def prev=(other)
    @order ||=
      if other.nil?
        nil
      elsif other.next&.order
        (other.next.order + other.order) / 2.0
      else
        other.order + 1
      end
    super
  end
end
