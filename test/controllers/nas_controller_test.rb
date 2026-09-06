require "test_helper"
require "minitest/mock"

class NasControllerTest < PersonalFinance::IntegrationTest
  test "owner sees NAS in hub and configuration state" do
    get root_path
    assert_select "a[href='#{nas_path}']"
    NasClient.stub :configured?, false do
      get nas_path
      assert_response :success
      assert_select "h1", "NAS Dosyaları"
      assert_select "h2", "Bağlantı bekleniyor"
    end
  end

  test "non owners cannot access any NAS operation" do
    User.dashboard_owner.update!(role: "viewer", email: "nas-viewer@example.com")
    get nas_path
    assert_response :forbidden
    get download_nas_path(path: "/file")
    assert_response :forbidden
    post upload_nas_path
    assert_response :forbidden
    post folder_nas_path
    assert_response :forbidden
    delete nas_path
    assert_response :forbidden
    get root_path
    assert_select "a[href='#{nas_path}']", count: 0
  end

  test "unauthenticated request redirects to login" do
    delete session_path
    get nas_path
    assert_redirected_to new_session_path
  end

  test "listing escapes untrusted filenames and displays metrics" do
    listing = {"path" => "/", "files" => [{"name" => "<script>x</script>", "path" => "/file", "is_dir" => false, "size" => 12, "modified" => 0}], "total" => 1, "page" => 1, "summary" => {"files" => 1, "folders" => 0, "bytes" => 12}, "latency_ms" => 5, "checked_at" => Time.current.iso8601}
    client = Minitest::Mock.new
    client.expect :browse, listing, [], path: "/", q: nil, sort: nil, page: nil
    NasClient.stub :configured?, true do
      NasClient.stub :new, client do
        get nas_path
        assert_response :success
        assert_select ".nas-file-name script", count: 0
        assert_select ".nas-metrics strong", text: "Erişilebilir"
        assert_equal "no-store", response.headers["Cache-Control"]
      end
    end
    client.verify
  end
  test "download streams attachment through the full middleware stack" do
    temporary_path = nil
    client = Object.new
    client.define_singleton_method(:download) do |path, file:|
      temporary_path = file.path
      file.write("test-download-content")
      file.rewind
      file
    end
    NasClient.stub :new, client do
      get download_nas_path(path: "/photo.jpg")
      assert_response :success
      assert_equal "test-download-content", response.body
      assert_includes response.headers["Content-Disposition"], "attachment"
      assert_includes response.headers["Content-Disposition"], "photo.jpg"
    end
    refute File.exist?(temporary_path), "temporary download must be removed when the response closes"
  end

  test "NAS sidebar and language switcher render in both locales" do
    NasClient.stub :configured?, false do
      get nas_path(locale: :en)
      assert_response :success
      assert_select "h1", "NAS Files"
      assert_select ".sidebar", count: 1
      assert_select ".sidebar .language-switcher", count: 1
      assert_select ".sidebar a", text: "All files"
      get nas_path(locale: :tr)
      assert_response :success
      assert_select ".sidebar a", text: "Tüm dosyalar"
    end
  end
end
