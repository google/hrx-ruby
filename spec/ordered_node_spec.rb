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

require 'hrx'

RSpec.describe HRX::OrderedNode do
  context "a list of ordered nodes" do
    subject do
      LinkedList::List.new <<
        HRX::OrderedNode.new("do") <<
        HRX::OrderedNode.new("re") <<
        HRX::OrderedNode.new("me") <<
        HRX::OrderedNode.new("fa") <<
        HRX::OrderedNode.new("so")
    end

    def it_should_be_ordered
      subject.each_node.each_cons(2) do |n1, n2|
        expect(n1.order).to be < n2.order
      end
    end

    it "should begin ordered" do
      it_should_be_ordered
    end

    it "should remain ordered when a node is deleted" do
      subject.delete "me"
      it_should_be_ordered
    end

    it "should remain ordered when a node is added at the beginning" do
      subject.unshift HRX::OrderedNode.new("ti")
      it_should_be_ordered
    end

    it "should remain ordered when a node is added in the middle" do
      subject.insert HRX::OrderedNode.new("re#"), after: "re"
      it_should_be_ordered
    end

    it "should remain ordered when a node is added at the end" do
      subject << HRX::OrderedNode.new("la")
      it_should_be_ordered
    end
  end
end
