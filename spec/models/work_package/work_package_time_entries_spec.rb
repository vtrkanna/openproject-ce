#-- copyright
# OpenProject is a project management system.
# Copyright (C) 2012-2013 the OpenProject Foundation (OPF)
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See doc/COPYRIGHT.rdoc for more details.
#++

require 'spec_helper'

describe WorkPackage do
  let(:work_package) { FactoryGirl.create(:work_package, :project => project,
                                                         :status => status) }
  let(:work_package2) { FactoryGirl.create(:work_package, :project => project2,
                                                          :status => status) }
  let(:user) { FactoryGirl.create(:user) }

  let(:type) { FactoryGirl.create(:type_standard) }
  let(:project) { FactoryGirl.create(:project, types: [type]) }
  let(:project2) { FactoryGirl.create(:project, types: [type]) }
  let(:role) { FactoryGirl.create(:role) }
  let(:role2) { FactoryGirl.create(:role) }
  let(:member) { FactoryGirl.create(:member, :principal => user,
                                             :roles => [role]) }
  let(:member2) { FactoryGirl.create(:member, :principal => user,
                                              :roles => [role2],
                                              :project => work_package2.project) }
  let(:status) { FactoryGirl.create(:status) }
  let(:priority) { FactoryGirl.create(:priority) }
  let(:time_entry) { FactoryGirl.build(:time_entry, :work_package => work_package,
                                                    :project => work_package.project) }
  let(:time_entry2) { FactoryGirl.build(:time_entry, :work_package => work_package2,
                                                     :project => work_package2.project) }

  describe :time_entry_hours_on do
    describe 'w/ the work package having a time entry' do
      before do
        work_package
        time_entry.hours = 10.0
        time_entry.save!
      end

      it "should calculate the sum of the work_package's time entries" do
        WorkPackage.time_entry_hours_on(work_package).should == 10.0
      end
    end

    describe 'w/o the work package having a time entry' do
      before do
        work_package
      end

      it "should calculate the sum of the work_package's time entries" do
        WorkPackage.time_entry_hours_on(work_package).should == 0.0
      end
    end

    describe 'w/ two work packages having a time entry' do
      before do
        work_package
        time_entry.hours = 10.0
        time_entry2.hours = 10.0
        time_entry.save!
        time_entry2.save!
      end

      it "should calculate the sum of the work_packages' time entries" do
        WorkPackage.time_entry_hours_on([work_package, work_package2]).should == 20.0
      end
    end
  end

  describe :cleanup_time_entries_if_required do
    before do
      work_package.save!

      time_entry.hours = 10
      time_entry.save!
    end

    describe 'w/o a cleanup beeing necessary' do
      let(:action) { WorkPackage.cleanup_time_entries_if_required(work_package, user, :action => 'reassign') }

      before do
        time_entry.destroy
      end

      it 'should return true' do
        action.should be_true
      end
    end

    describe 'w/ "destroy" as action' do
      let(:action) { WorkPackage.cleanup_time_entries_if_required(work_package, user, :action => 'destroy') }

      it 'should return true' do
        action.should be_true
      end

      it 'should not touch the time_entry' do
        action

        time_entry.reload
        time_entry.work_package_id.should == work_package.id
      end
    end

    describe 'w/o an action' do
      let(:action) { WorkPackage.cleanup_time_entries_if_required(work_package, user) }

      it 'should return true' do
        action.should be_true
      end

      it 'should not touch the time_entry' do
        action

        time_entry.reload
        time_entry.work_package_id.should == work_package.id
      end
    end

    describe 'w/ "nullify" as action' do
      let(:action) { WorkPackage.cleanup_time_entries_if_required(work_package, user, :action => 'nullify') }

      it 'should return true' do
        action.should be_true
      end

      it 'should set the work_package_id of all time entries to nil' do
        action

        time_entry.reload
        time_entry.work_package_id.should be_nil
      end
    end

    describe 'w/ "reassign" as action
              w/ reassigning to a valid work_package' do
      let(:action) { WorkPackage.cleanup_time_entries_if_required(work_package, user, :action => 'reassign', :reassign_to_id => work_package2.id) }

      before do
        work_package2.save!
        role2.permissions << :edit_time_entries
        role2.save!
        member2.save!
      end

      it 'should return true' do
        action.should be_true
      end

      it 'should set the work_package_id of all time entries to the new work package' do
        action

        time_entry.reload
        time_entry.work_package_id.should == work_package2.id
      end

      it "should set the project_id of all time entries to the new work package's project" do
        action

        time_entry.reload
        time_entry.project_id.should == work_package2.project_id
      end
    end

    describe 'w/ "reassign" as action
              w/ reassigning to a work_package the user is not allowed to see' do
      let(:action) { WorkPackage.cleanup_time_entries_if_required(work_package, user, :action => 'reassign', :reassign_to_id => work_package2.id) }

      before do
        work_package2.save!
      end

      it 'should return true' do
        action.should be_false
      end

      it 'should not alter the work_package_id of all time entries' do
        action

        time_entry.reload
        time_entry.work_package_id.should == work_package.id
      end
    end

    describe 'w/ "reassign" as action
              w/ reassigning to a non existing work package' do
      let(:action) { WorkPackage.cleanup_time_entries_if_required(work_package, user, :action => 'reassign', :reassign_to_id => 0) }

      it 'should return true' do
        action.should be_false
      end

      it 'should not alter the work_package_id of all time entries' do
        action

        time_entry.reload
        time_entry.work_package_id.should == work_package.id
      end
    end

    describe 'w/ "reassign" as action
              w/o providing a reassignment id' do
      let(:action) { WorkPackage.cleanup_time_entries_if_required(work_package, user, :action => 'reassign') }

      it 'should return true' do
        action.should be_false
      end

      it 'should not alter the work_package_id of all time entries' do
        action

        time_entry.reload
        time_entry.work_package_id.should == work_package.id
      end
    end

    describe 'w/ an invalid option' do
      let(:action) { WorkPackage.cleanup_time_entries_if_required(work_package, user, :action => 'bogus') }

      it 'should return false' do
        action.should be_false
      end
    end

    describe 'w/ nil as invalid option' do
      let(:action) { WorkPackage.cleanup_time_entries_if_required(work_package, user, nil) }

      it 'should return false' do
        action.should be_false
      end
    end
  end
end
