require 'support/spec_support'
require 'chef/resource/chef_node'
require 'chef/provider/chef_node'

describe Chef::Resource::ChefNode do
  extend SpecSupport

  when_the_chef_12_server 'is in multi-org mode' do
    organization 'foo'

    before :each do
      Chef::Config.chef_server_url = URI.join(Chef::Config.chef_server_url, '/organizations/foo').to_s
    end

    context 'and is empty' do
      context 'and we run a recipe that creates node "blah"' do
        with_converge do
          chef_node 'blah'
        end

        it 'the node gets created' do
          expect(chef_run).to have_updated 'chef_node[blah]', :create
          expect(get('nodes/blah')['name']).to eq('blah')
        end
      end

      # TODO why-run mode

      context 'and another chef server is running on port 8899' do
        before :each do
          @server = ChefZero::Server.new(:port => 8899)
          @server.start_background
        end

        after :each do
          @server.stop
        end

        context 'and a recipe is run that creates node "blah" on the second chef server using with_chef_server' do

          with_converge do
            with_chef_server 'http://127.0.0.1:8899'
            chef_node 'blah'
          end

          it 'the node is created on the second chef server but not the first' do
            expect(chef_run).to have_updated 'chef_node[blah]', :create
            expect { get('nodes/blah') }.to raise_error(Net::HTTPServerException)
            expect(get('http://127.0.0.1:8899/nodes/blah')['name']).to eq('blah')
          end
        end

        context 'and a recipe is run that creates node "blah" on the second chef server using chef_server' do

          with_converge do
            chef_node 'blah' do
              chef_server({ :chef_server_url => 'http://127.0.0.1:8899' })
            end
          end

          it 'the node is created on the second chef server but not the first' do
            expect(chef_run).to have_updated 'chef_node[blah]', :create
            expect { get('nodes/blah') }.to raise_error(Net::HTTPServerException)
            expect(get('http://127.0.0.1:8899/nodes/blah')['name']).to eq('blah')
          end
        end
      end
    end

    context 'and has a node named "blah"' do
      node 'blah', {}

      with_converge do
        chef_node 'blah'
      end

      it 'chef_node "blah" does not get created or updated' do
        expect(chef_run).not_to have_updated 'chef_node[blah]', :create
      end
    end

    context 'and has a node named "blah" with tags' do
      node 'blah', {
        'normal' => { 'tags' => [ 'a', 'b' ] }
      }

      context 'with chef_node "blah" that sets attributes' do
        with_converge do
          chef_node 'blah' do
            attributes({})
          end
        end

        it 'the tags in attributes are used' do
          expect(get('nodes/blah')['normal']['tags']).to eq([ 'a', 'b' ])
        end
      end

      context 'with chef_node "blah" that sets attributes with tags in them' do
        with_converge do
          chef_node 'blah' do
            attributes 'tags' => [ 'c', 'd' ]
          end
        end

        it 'the tags in attributes are used' do
          expect(get('nodes/blah')['normal']['tags']).to eq([ 'c', 'd' ])
        end
      end
    end

    describe '#complete' do
      context 'when the Chef server has a node named "blah" with everything in it' do
        node 'blah', {
          'chef_environment' => 'blah',
          'run_list'  => [ 'recipe[bjork]' ],
          'normal'    => { 'foo' => 'bar', 'tags' => [ 'a', 'b' ] },
          'default'   => { 'foo2' => 'bar2' },
          'automatic' => { 'foo3' => 'bar3' },
          'override'  => { 'foo4' => 'bar4' }
        }

        it 'chef_node with no attributes modifies nothing' do
          run_recipe do
            chef_node 'blah'
          end
          expect(get('nodes/blah')).to include(
            'name' => 'blah',
            'chef_environment' => 'blah',
            'run_list'  => [ 'recipe[bjork]' ],
            'normal'    => { 'foo' => 'bar', 'tags' => [ 'a', 'b' ] },
            'default'   => { 'foo2' => 'bar2' },
            'automatic' => { 'foo3' => 'bar3' },
            'override'  => { 'foo4' => 'bar4' }
          )
        end

        it 'chef_node with complete true removes everything except default, automatic and override' do
          run_recipe do
            chef_node 'blah' do
              complete true
            end
          end
          expect(get('nodes/blah')).to include(
            'name' => 'blah',
            'chef_environment' => '_default',
            'run_list'  => [ ],
            'normal'    => { 'tags' => [ 'a', 'b' ] },
            'default'   => { 'foo2' => 'bar2' },
            'automatic' => { 'foo3' => 'bar3' },
            'override'  => { 'foo4' => 'bar4' }
          )
        end

        it 'chef_node with complete true sets the given attributes' do
          run_recipe do
            chef_node 'blah' do
              chef_environment 'x'
              run_list [ 'recipe[y]' ]
              attributes 'a' => 'b'
              tags 'c', 'd'
              complete true
            end
          end
          expect(get('nodes/blah')).to include(
            'name' => 'blah',
            'chef_environment' => 'x',
            'run_list'  => [ 'recipe[y]' ],
            'normal'    => { 'a' => 'b', 'tags' => [ 'c', 'd' ] },
            'default'   => { 'foo2' => 'bar2' },
            'automatic' => { 'foo3' => 'bar3' },
            'override'  => { 'foo4' => 'bar4' }
          )
        end

        it 'chef_node with complete true and partial attributes sets the given attributes' do
          run_recipe do
            chef_node 'blah' do
              chef_environment 'x'
              recipe 'y'
              attribute 'a', 'b'
              tags 'c', 'd'
              complete true
            end
          end
          expect(get('nodes/blah')).to include(
            'name' => 'blah',
            'chef_environment' => 'x',
            'run_list'  => [ 'recipe[y]' ],
            'normal'    => { 'a' => 'b', 'tags' => [ 'c', 'd' ] },
            'default'   => { 'foo2' => 'bar2' },
            'automatic' => { 'foo3' => 'bar3' },
            'override'  => { 'foo4' => 'bar4' }
          )
        end
      end
    end

    describe '#attributes' do
      context 'with a node with normal attributes a => b and c => { d => e }' do
        node 'blah', {
          'normal' => {
            'a' => 'b',
            'c' => { 'd' => 'e' },
            'tags' => [ 'a', 'b' ]
          },
          'automatic' => {
            'x' => 'y'
          },
          'chef_environment' => 'desert'
        }

        it 'chef_node with attributes {} removes all normal attributes but leaves tags, automatic and environment alone' do
          run_recipe do
            chef_node 'blah' do
              attributes({})
            end
          end
          expect(chef_run).to have_updated('chef_node[blah]', :create)
          expect(get('nodes/blah')).to include(
            'normal' => { 'tags' => [ 'a', 'b' ] },
            'automatic' => { 'x' => 'y' },
            'chef_environment' => 'desert'
          )
        end

        it 'chef_node with attributes { c => d } replaces normal but not tags/automatic/environment' do
          run_recipe do
            chef_node 'blah' do
              attributes 'c' => 'd'
            end
          end
          expect(chef_run).to have_updated('chef_node[blah]', :create)
          expect(get('nodes/blah')).to include(
            'normal' => { 'c' => 'd', 'tags' => [ 'a', 'b' ] },
            'automatic' => { 'x' => 'y' },
            'chef_environment' => 'desert'
          )
        end

        it 'chef_node with attributes { c => f => g, y => z } replaces normal but not tags/automatic/environment' do
          run_recipe do
            chef_node 'blah' do
              attributes 'c' => { 'f' => 'g' }, 'y' => 'z'
            end
          end
          expect(chef_run).to have_updated('chef_node[blah]', :create)
          expect(get('nodes/blah')).to include(
            'normal' => { 'c' => { 'f' => 'g' }, 'y' => 'z', 'tags' => [ 'a', 'b' ] },
            'automatic' => { 'x' => 'y' },
            'chef_environment' => 'desert'
          )
        end

        it 'chef_node with attributes { tags => [ "x" ] } replaces normal and tags but not automatic/environment' do
          run_recipe do
            chef_node 'blah' do
              attributes 'tags' => [ 'x' ]
            end
          end
          expect(chef_run).to have_updated('chef_node[blah]', :create)
          expect(get('nodes/blah')).to include(
            'normal' => { 'tags' => [ 'x' ] },
            'automatic' => { 'x' => 'y' },
            'chef_environment' => 'desert'
          )
        end

        it 'chef_node with tags "x" and attributes { "tags" => [ "y" ] } sets tags to "x"' do
          run_recipe do
            chef_node 'blah' do
              tags 'x'
              attributes 'tags' => [ 'y' ]
            end
          end
          expect(chef_run).to have_updated('chef_node[blah]', :create)
          expect(get('nodes/blah')).to include(
            'normal' => {
              'tags' => [ 'x' ]
            },
            'automatic' => { 'x' => 'y' },
            'chef_environment' => 'desert'
          )
        end
      end
    end

    describe '#attribute' do
      context 'with a node with normal attributes a => b and c => { d => e }' do
        node 'blah', {
          'normal' => {
            'a' => 'b',
            'c' => { 'd' => 'e' },
            'tags' => [ 'a', 'b' ]
          },
          'automatic' => {
            'x' => 'y'
          },
          'chef_environment' => 'desert'
        }

        context 'basic scenarios' do
          it 'chef_node with no attributes, leaves it alone' do
            run_recipe do
              chef_node 'blah'
            end
            expect(chef_run).not_to have_updated('chef_node[blah]', :create)
            expect(get('nodes/blah')).to include(
              'normal' => {
                'a' => 'b',
                'c' => { 'd' => 'e' },
                'tags' => [ 'a', 'b' ]
              },
              'automatic' => { 'x' => 'y' },
              'chef_environment' => 'desert'
            )
          end

          it 'chef_node with attribute d, e adds the attribute' do
            run_recipe do
              chef_node 'blah' do
                attribute 'd', 'e'
              end
            end
            expect(chef_run).to have_updated('chef_node[blah]', :create)
            expect(get('nodes/blah')).to include(
              'normal' => {
                'a' => 'b',
                'c' => { 'd' => 'e' },
                'd' => 'e',
                'tags' => [ 'a', 'b' ]
              },
              'automatic' => { 'x' => 'y' },
              'chef_environment' => 'desert'
            )
          end

          it 'chef_node with attribute tags, [ "x" ] replaces tags' do
            run_recipe do
              chef_node 'blah' do
                attribute 'tags', [ 'x' ]
              end
            end
            expect(chef_run).to have_updated('chef_node[blah]', :create)
            expect(get('nodes/blah')).to include(
              'normal' => {
                'a' => 'b',
                'c' => { 'd' => 'e' },
                'tags' => [ 'x' ]
              },
              'automatic' => { 'x' => 'y' },
              'chef_environment' => 'desert'
            )
          end

          it 'chef_node with attribute c, x replaces the attribute' do
            run_recipe do
              chef_node 'blah' do
                attribute 'c', 'x'
              end
            end
            expect(chef_run).to have_updated('chef_node[blah]', :create)
            expect(get('nodes/blah')).to include(
              'normal' => {
                'a' => 'b',
                'c' => 'x',
                'tags' => [ 'a', 'b' ]
              },
              'automatic' => { 'x' => 'y' },
              'chef_environment' => 'desert'
            )
          end

          it 'chef_node with attribute c, { d => x } replaces the attribute' do
            run_recipe do
              chef_node 'blah' do
                attribute 'c', { 'd' => 'x' }
              end
            end
            expect(chef_run).to have_updated('chef_node[blah]', :create)
            expect(get('nodes/blah')).to include(
              'normal' => {
                'a' => 'b',
                'c' => { 'd' => 'x' },
                'tags' => [ 'a', 'b' ]
              },
              'automatic' => { 'x' => 'y' },
              'chef_environment' => 'desert'
            )
          end

          it 'chef_node with attribute [ c, d ], x replaces the attribute' do
            run_recipe do
              chef_node 'blah' do
                attribute [ 'c', 'd' ], 'x'
              end
            end
            expect(chef_run).to have_updated('chef_node[blah]', :create)
            expect(get('nodes/blah')).to include(
              'normal' => {
                'a' => 'b',
                'c' => { 'd' => 'x' },
                'tags' => [ 'a', 'b' ]
              },
              'automatic' => { 'x' => 'y' },
              'chef_environment' => 'desert'
            )
          end

          it 'chef_node with attribute [ a, b ], x raises an error' do
            expect do
              run_recipe do
                chef_node 'blah' do
                  attribute [ 'a', 'b' ], 'x'
                end
              end
            end.to raise_error /Attempt to set \["a", "b"\] to x when \["a"\] is not a hash/
          end

          it 'chef_node with attribute [ a, b, c ], x raises an error' do
            expect do
              run_recipe do
                chef_node 'blah' do
                  attribute [ 'a', 'b', 'c' ], 'x'
                end
              end
            end.to raise_error /Attempt to set \["a", "b", "c"\] to x when \["a"\] is not a hash/
          end

          it 'chef_node with attribute [ x, y ], z adds a new attribute' do
            run_recipe do
              chef_node 'blah' do
                attribute [ 'x', 'y' ], 'z'
              end
            end
            expect(chef_run).to have_updated('chef_node[blah]', :create)
            expect(get('nodes/blah')).to include(
              'normal' => {
                'a' => 'b',
                'c' => { 'd' => 'e' },
                'x' => { 'y' => 'z' },
                'tags' => [ 'a', 'b' ]
              },
              'automatic' => { 'x' => 'y' },
              'chef_environment' => 'desert'
            )
          end
        end

        context 'delete' do
          it 'chef_node with attribute a, :delete deletes the attribute' do
            run_recipe do
              chef_node 'blah' do
                attribute 'a', :delete
              end
            end
            expect(chef_run).to have_updated('chef_node[blah]', :create)
            expect(get('nodes/blah')).to include(
              'normal' => {
                'c' => { 'd' => 'e' },
                'tags' => [ 'a', 'b' ]
              },
              'automatic' => { 'x' => 'y' },
              'chef_environment' => 'desert'
            )
          end

          it 'chef_node with attribute c, :delete deletes the attribute' do
            run_recipe do
              chef_node 'blah' do
                attribute 'c', :delete
              end
            end
            expect(chef_run).to have_updated('chef_node[blah]', :create)
            expect(get('nodes/blah')).to include(
              'normal' => {
                'a' => 'b',
                'tags' => [ 'a', 'b' ]
              },
              'automatic' => { 'x' => 'y' },
              'chef_environment' => 'desert'
            )
          end

          it 'chef_node with attribute [ c, d ], :delete deletes the attribute' do
            run_recipe do
              chef_node 'blah' do
                attribute [ 'c', 'd' ], :delete
              end
            end
            expect(chef_run).to have_updated('chef_node[blah]', :create)
            expect(get('nodes/blah')).to include(
              'normal' => {
                'a' => 'b',
                'c' => {},
                'tags' => [ 'a', 'b' ]
              },
              'automatic' => { 'x' => 'y' },
              'chef_environment' => 'desert'
            )
          end

          it 'chef_node with attribute xyz, :delete does nothing' do
            run_recipe do
              chef_node 'blah' do
                attribute 'xyz', :delete
              end
            end
            expect(chef_run).not_to have_updated('chef_node[blah]', :create)
            expect(get('nodes/blah')).to include(
              'normal' => {
                'a' => 'b',
                'c' => { 'd' => 'e' },
                'tags' => [ 'a', 'b' ]
              },
              'automatic' => { 'x' => 'y' },
              'chef_environment' => 'desert'
            )
          end

          it 'chef_node with attribute [ c, x ], :delete does nothing' do
            run_recipe do
              chef_node 'blah' do
                attribute [ 'c', 'x' ], :delete
              end
            end
            expect(chef_run).not_to have_updated('chef_node[blah]', :create)
            expect(get('nodes/blah')).to include(
              'normal' => {
                'a' => 'b',
                'c' => { 'd' => 'e' },
                'tags' => [ 'a', 'b' ]
              },
              'automatic' => { 'x' => 'y' },
              'chef_environment' => 'desert'
            )
          end
        end

        context 'types' do
          it 'chef_node with attribute a, true sets a to true' do
            run_recipe do
              chef_node 'blah' do
                attribute 'a', true
              end
            end
            expect(get('nodes/blah')).to include(
              'normal' => {
                'a' => true,
                'c' => { 'd' => 'e' },
                'tags' => [ 'a', 'b' ]
              },
              'automatic' => { 'x' => 'y' },
              'chef_environment' => 'desert'
            )
          end

          it 'chef_node with attribute a, 1 sets a to 1' do
            run_recipe do
              chef_node 'blah' do
                attribute 'a', 1
              end
            end
            expect(get('nodes/blah')).to include(
              'normal' => {
                'a' => 1,
                'c' => { 'd' => 'e' },
                'tags' => [ 'a', 'b' ]
              },
              'automatic' => { 'x' => 'y' },
              'chef_environment' => 'desert'
            )
          end

          it 'chef_node with attribute a, "1" sets a to "1"' do
            run_recipe do
              chef_node 'blah' do
                attribute 'a', "1"
              end
            end
            expect(get('nodes/blah')).to include(
              'normal' => {
                'a' => "1",
                'c' => { 'd' => 'e' },
                'tags' => [ 'a', 'b' ]
              },
              'automatic' => { 'x' => 'y' },
              'chef_environment' => 'desert'
            )
          end

          it 'chef_node with attribute a, "" sets a to ""' do
            run_recipe do
              chef_node 'blah' do
                attribute 'a', ""
              end
            end
            expect(get('nodes/blah')).to include(
              'normal' => {
                'a' => "",
                'c' => { 'd' => 'e' },
                'tags' => [ 'a', 'b' ]
              },
              'automatic' => { 'x' => 'y' },
              'chef_environment' => 'desert'
            )
          end

          it 'chef_node with attribute a, nil sets a to nil' do
            run_recipe do
              chef_node 'blah' do
                attribute 'a', nil
              end
            end
            expect(get('nodes/blah')).to include(
              'normal' => {
                'a' => nil,
                'c' => { 'd' => 'e' },
                'tags' => [ 'a', 'b' ]
              },
              'automatic' => { 'x' => 'y' },
              'chef_environment' => 'desert'
            )
          end
        end

        context 'multiple attribute definitions' do
          it 'chef_node with attribute a, x and c, y replaces both attributes' do
            run_recipe do
              chef_node 'blah' do
                attribute 'a', 'x'
                attribute 'c', 'y'
              end
            end
            expect(get('nodes/blah')).to include(
              'normal' => {
                'a' => 'x',
                'c' => 'y',
                'tags' => [ 'a', 'b' ]
              },
              'automatic' => { 'x' => 'y' },
              'chef_environment' => 'desert'
            )
          end

          it 'chef_node with attribute m, x and n, y adds both attributes' do
            run_recipe do
              chef_node 'blah' do
                attribute 'm', 'x'
                attribute 'n', 'y'
              end
            end
            expect(get('nodes/blah')).to include(
              'normal' => {
                'a' => 'b',
                'c' => { 'd' => 'e' },
                'm' => 'x',
                'n' => 'y',
                'tags' => [ 'a', 'b' ]
              },
              'automatic' => { 'x' => 'y' },
              'chef_environment' => 'desert'
            )
          end

          it 'chef_node with attribute [x, y], z and [x, yy], zz adds both attributes' do
            run_recipe do
              chef_node 'blah' do
                attribute [ 'x', 'y' ], 'z'
                attribute [ 'x', 'yy' ], 'zz'
              end
            end
            expect(get('nodes/blah')).to include(
              'normal' => {
                'a' => 'b',
                'c' => { 'd' => 'e' },
                'x' => {
                  'y' => 'z',
                  'yy' => 'zz'
                },
                'tags' => [ 'a', 'b' ]
              },
              'automatic' => { 'x' => 'y' },
              'chef_environment' => 'desert'
            )
          end

          describe 'precedence' do
            it 'chef_node with attribute a, 1 and a, 2 sets a to 2' do
              run_recipe do
                chef_node 'blah' do
                  attribute 'a', 1
                  attribute 'a', 2
                end
              end
              expect(get('nodes/blah')).to include(
                'normal' => {
                  'a' => 2,
                  'c' => { 'd' => 'e' },
                  'tags' => [ 'a', 'b' ]
                },
                'automatic' => { 'x' => 'y' },
                'chef_environment' => 'desert'
              )
            end

            it 'chef_node with attribute [ x, y ], 1 and [ x, y ], 2 sets [ x, y ], 2' do
              run_recipe do
                chef_node 'blah' do
                  attribute [ 'x', 'y' ], 1
                  attribute [ 'x', 'y' ], 2
                end
              end
              expect(get('nodes/blah')).to include(
                'normal' => {
                  'a' => 'b',
                  'c' => { 'd' => 'e' },
                  'x' => { 'y' => 2 },
                  'tags' => [ 'a', 'b' ]
                },
                'automatic' => { 'x' => 'y' },
                'chef_environment' => 'desert'
              )
            end

            it 'chef_node with attribute [ c, e ], { a => 1 }, [ c, e ], { b => 2 } sets b only' do
              run_recipe do
                chef_node 'blah' do
                  attribute [ 'c', 'e' ], { 'a' => 1 }
                  attribute [ 'c', 'e' ], { 'b' => 2 }
                end
              end
              expect(get('nodes/blah')).to include(
                'normal' => {
                  'a' => 'b',
                  'c' => { 'd' => 'e', 'e' => { 'b' => 2 } },
                  'tags' => [ 'a', 'b' ]
                },
                'automatic' => { 'x' => 'y' },
                'chef_environment' => 'desert'
              )
            end

            it 'chef_node with attribute [ c, e ], { a => 1 }, [ c, e, b ], 2 sets both' do
              run_recipe do
                chef_node 'blah' do
                  attribute [ 'c', 'e' ], { 'a' => 1 }
                  attribute [ 'c', 'e', 'b' ], 2
                end
              end
              expect(get('nodes/blah')).to include(
                'normal' => {
                  'a' => 'b',
                  'c' => { 'd' => 'e', 'e' => { 'a' => 1, 'b' => 2 } },
                  'tags' => [ 'a', 'b' ]
                },
                'automatic' => { 'x' => 'y' },
                'chef_environment' => 'desert'
              )
            end

            it 'chef_node with attribute [ c, e, b ], 2, [ c, e ], { a => 1 } sets a only' do
              run_recipe do
                chef_node 'blah' do
                  attribute [ 'c', 'e', 'b' ], 2
                  attribute [ 'c', 'e' ], { 'a' => 1 }
                end
              end
              expect(get('nodes/blah')).to include(
                'normal' => {
                  'a' => 'b',
                  'c' => { 'd' => 'e', 'e' => { 'a' => 1 } },
                  'tags' => [ 'a', 'b' ]
                },
                'automatic' => { 'x' => 'y' },
                'chef_environment' => 'desert'
              )
            end
          end
        end
      end
    end
  end

  when_the_chef_server 'is in OSC mode' do
    context 'and is empty' do
      context 'and we run a recipe that creates node "blah"' do
        with_converge do
          chef_node 'blah'
        end

        it 'the node gets created' do
          expect(chef_run).to have_updated 'chef_node[blah]', :create
          expect(get('nodes/blah')['name']).to eq('blah')
        end
      end
    end
  end
end
