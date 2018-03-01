require 'spec_helper'

describe 'oracle_inventory' do
  on_supported_os(facterversion: '2.4').each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to contain_package('xml-simple') }

      context 'without any parameters' do
        it { is_expected.to compile.with_all_deps }

        os =~ %r{windows}i or it { is_expected.to contain_class('oracle_inventory::inventory_pointer') }
      end

      context 'without managing pointer file' do
        let(:params) { { 'manage_pointer' => false } }

        it { is_expected.not_to contain_class('oracle_inventory::inventory_pointer') }
      end
    end
  end
end
