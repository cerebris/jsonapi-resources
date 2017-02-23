require File.expand_path('../test_helper', __FILE__)

class BugReportTemplatesTest < ActiveSupport::TestCase

  def jsonapi_resources_root
    File.expand_path('../..', __FILE__)
  end

  def chdir_path
    File.join(jsonapi_resources_root, 'lib', 'bug_report_templates')
  end

  def assert_bug_report(file_name)
    Bundler.with_clean_env do
      Dir.chdir(chdir_path) do
        assert system({'JSONAPI_RESOURCES_PATH' => jsonapi_resources_root}, Gem.ruby, file_name)
      end
    end
  end

  def test_rails_5
    assert_bug_report 'rails_5_master.rb'
  end

end
