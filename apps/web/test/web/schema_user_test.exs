defmodule Web.SchemaUserTest do
  use Web.DataCase

  alias Web.Schema
  alias Web.QueryRegistration, as: RegQuery
  alias Data.FactoryRegistration, as: RegFactory
  alias Web.QueryUser, as: Query
  alias Data.FactoryUser, as: Factory
  alias Web.Guardian

  @moduletag :db

  describe "mutation" do
    # @tag :skip
    test "registers user succeeds" do
      %{
        "name" => name,
        "email" => email
      } =
        attrs =
        RegFactory.params()
        |> RegFactory.stringify()

      queryMap = RegQuery.register()

      query = """
        mutation RegisterUser(#{queryMap.parameters}) {
          #{queryMap.query}
        }

        #{queryMap.fragments}
      """

      assert {:ok,
              %{
                data: %{
                  "registration" => %{
                    "id" => _,
                    "name" => ^name,
                    "email" => ^email,
                    "jwt" => _jwt,
                    "credential" => %{
                      "id" => _
                    }
                  }
                }
              }} =
               Absinthe.run(query, Schema,
                 variables: %{
                   "registration" => attrs
                 }
               )
    end

    # @tag :skip
    test "registers user fails for none unique email" do
      attrs = RegFactory.params()

      RegFactory.insert(attrs)
      queryMap = RegQuery.register()

      query = """
        mutation RegisterUser(#{queryMap.parameters}) {
          #{queryMap.query}
        }

        #{queryMap.fragments}
      """

      error =
        %{
          errors: %{
            email: "has already been taken"
          },
          name: "user"
        }
        |> Jason.encode!()

      assert {:ok,
              %{
                errors: [
                  %{
                    message: ^error,
                    path: ["registration"]
                  }
                ]
              }} =
               Absinthe.run(query, Schema,
                 variables: %{
                   "registration" => RegFactory.stringify(attrs)
                 }
               )
    end

    # @tag :skip
    test "update user succeeds" do
      user = RegFactory.insert()
      {:ok, jwt, _claim} = Guardian.encode_and_sign(user)

      attrs =
        Factory.params(jwt: jwt)
        |> RegFactory.stringify()

      queryMap = Query.update()

      query = """
        mutation updateUser(#{queryMap.parameters}) {
          #{queryMap.query}
        }

        #{queryMap.fragments}
      """

      assert {:ok,
              %{
                data: %{
                  "update" => %{
                    "id" => _,
                    "name" => name,
                    "email" => email,
                    "jwt" => _jwt
                  }
                }
              }} =
               Absinthe.run(query, Schema,
                 variables: %{
                   "user" => attrs
                 }
               )

      refute user.name == name
      refute user.email == email
    end

    # @tag :skip
    test "login succeeds" do
      %{email: email, password: password} = params = RegFactory.params()
      RegFactory.insert(params)
      queryMap = Query.login()

      query = """
        mutation LoginUser(#{queryMap.parameters}) {
          #{queryMap.query}
        }

        #{queryMap.fragments}
      """

      variables = %{
        "login" => %{
          "email" => email,
          "password" => password
        }
      }

      assert {:ok,
              %{
                data: %{
                  "login" => %{
                    "id" => _,
                    "name" => name,
                    "email" => ^email,
                    "jwt" => _jwt
                  }
                }
              }} = Absinthe.run(query, Schema, variables: variables)
    end

    # @tag :skip
    test "login fails" do
      %{email: email, password: password} = params = RegFactory.params()
      RegFactory.insert(params)

      queryMap = Query.login()

      query = """
        mutation LoginUser(#{queryMap.parameters}) {
          #{queryMap.query}
        }

        #{queryMap.fragments}
      """

      password = password <> "q"

      assert {:ok,
              %{
                errors: [%{message: "{\"error\":\"Invalid email/password\"}"}]
              }} =
               Absinthe.run(query, Schema,
                 variables: %{
                   "login" => %{
                     "email" => email,
                     "password" => password
                   }
                 }
               )
    end
  end

  describe "query" do
    test "refreshes user succeeds with ok jwt" do
      user = RegFactory.insert()
      user_id = Integer.to_string(user.id)
      {:ok, jwt, _claims} = Guardian.encode_and_sign(user)

      queryMap = Query.refresh()

      query = """
        query RefreshUser(#{queryMap.parameters}) {
          #{queryMap.query}
        }

        #{queryMap.fragments}
      """

      assert {:ok,
              %{
                data: %{
                  "refresh" => %{"id" => ^user_id, "jwt" => new_jwt}
                }
              }} =
               Absinthe.run(query, Schema,
                 variables: %{
                   "refresh" => %{"jwt" => jwt}
                 }
               )

      refute jwt == new_jwt
    end

    test "refreshes user fails for tampered with jwt" do
      user = RegFactory.insert()
      {:ok, jwt, _claims} = Guardian.encode_and_sign(user)

      queryMap = Query.refresh()

      query = """
        query RefreshUser(#{queryMap.parameters}) {
          #{queryMap.query}
        }

        #{queryMap.fragments}
      """

      assert {:ok,
              %{
                data: %{"refresh" => nil},
                errors: [
                  %{
                    locations: [%{column: 0, line: 2}],
                    message: "{\"error\":\"invalid_token\"}",
                    path: ["refresh"]
                  }
                ]
              }} =
               Absinthe.run(query, Schema,
                 variables: %{
                   "refresh" => %{"jwt" => jwt <> "9"}
                 }
               )
    end
  end
end
