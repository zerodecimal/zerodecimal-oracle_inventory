require 'spec_helper'

describe 'oracle_inventory::inventory_pointer' do
  on_supported_os(facterversion: '2.4').each do |os, os_facts|
    next if os =~ %r{windows}i
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile.with_all_deps }

      context 'with default parameters' do
        let(:facts) do
          super().merge(
            'oracle_inventory_pointer' => '/etc/oraInst.loc',
            'oracle_inventory'         => '/u01/app/oraInventory/ContentsXML/inventory.xml',
          )
        end

        it do
          is_expected.to contain_file('/etc/oraInst.loc').with(
            'owner'   => 'root',
            'group'   => 'root',
            'mode'    => '0644',
            'content' => "inventory_loc=/u01/app/oraInventory\ninst_group=oinstall\n",
          )
        end
      end
    end
  end
end
