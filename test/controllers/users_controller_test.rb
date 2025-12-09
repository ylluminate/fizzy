require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  test "show" do
    sign_in_as :kevin

    get user_path(users(:david))
    assert_in_body users(:david).name
  end

  test "update oneself" do
    sign_in_as :kevin

    get edit_user_path(users(:kevin))
    assert_response :ok

    put user_path(users(:kevin)), params: { user: { name: "New Kevin" } }
    assert_redirected_to user_path(users(:kevin))
    assert_equal "New Kevin", users(:kevin).reload.name
  end

  test "update other as admin" do
    sign_in_as :kevin

    get edit_user_path(users(:david))
    assert_response :ok

    put user_path(users(:david)), params: { user: { name: "New David" } }
    assert_redirected_to user_path(users(:david))
    assert_equal "New David", users(:david).reload.name
  end

  test "destroy" do
    sign_in_as :kevin

    assert_difference -> { User.active.count }, -1 do
      delete user_path(users(:david))
    end

    assert_redirected_to users_path
    assert_nil User.active.find_by(id: users(:david).id)
  end

  test "admin cannot deactivate the owner" do
    sign_in_as :kevin

    assert users(:jason).owner?
    assert users(:jason).active

    assert_no_difference -> { User.active.count } do
      delete user_path(users(:jason))
    end

    assert_response :forbidden
    assert users(:jason).reload.active
  end

  test "non-admins cannot perform actions" do
    sign_in_as :jz

    put user_path(users(:david)), params: { user: { role: "admin" } }
    assert_response :forbidden

    delete user_path(users(:david))
    assert_response :forbidden
  end

  test "index as JSON" do
    sign_in_as :kevin

    get users_path, as: :json
    assert_response :success
    assert_equal users(:kevin).account.users.active.count, @response.parsed_body.count
  end

  test "show as JSON" do
    sign_in_as :kevin

    get user_path(users(:david)), as: :json
    assert_response :success
    assert_equal users(:david).name, @response.parsed_body["name"]
  end

  test "update as JSON" do
    sign_in_as :kevin

    put user_path(users(:david)), params: { user: { name: "New David" } }, as: :json

    assert_response :no_content
    assert_equal "New David", users(:david).reload.name
  end

  test "destroy as JSON" do
    sign_in_as :kevin

    assert_difference -> { User.active.count }, -1 do
      delete user_path(users(:david)), as: :json
    end

    assert_response :no_content
  end
end
