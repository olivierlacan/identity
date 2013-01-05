module Identity
  class Web < Sinatra::Base
    include SessionHelpers
    register Sinatra::Namespace

    configure do
      set :views, "#{Config.root}/views"
      Slim::Engine.set_default_options pretty: !Config.production?
    end

    get "/" do
      redirect to("/sessions/new")
    end

    namespace "/sessions" do
      get "/new" do
        erb :"sessions/new", layout: :"sessions/layout"
      end

      post do
        user, pass = params[:email], params[:password]
        token = perform_oauth_dance(user, pass)

        self.access_token            = token["access_token"]
        self.access_token_expires_at = Time.now + token["expires_in"]

        # if we know that we're in the middle of an authorization attempt,
        # continue it; otherwise go to dashboard
        if authorize_params
          authorize(authorize_params)
        else
          redirect to(Config.dashboard_url)
        end
      end

      delete do
        session.clear
        redirect to("/sessions/new")
      end
    end

    namespace "/oauth" do
      post "/authorize" do
        authorize_params =
          filter_params(%w{client_id respond_type scope state})

        # have the user login if we have no session for them or if we know
        # they're past their token's expiry
        if !self.access_token || Time.now > self.access_token_expires_at
          store_authorize_params_and_login(authorize_params)
        end

        # redirects back to the oauth client on success
        authorize(authorize_params)
      end

      post "/token" do
        redirect to("/sessions/new") if !token
        res = api.post(path: "/oauth/token", expects: 200,
          query: { code: params[:code], client_secret: params[:client_secret] })
        content_type(:json)
        [200, res.body]
      end
    end

    private

    def api
      @api ||= HerokuAPI.new(user: nil, pass: self.access_token)
    end

    def authorize(params)
      res = api.post(path: "/oauth/authorize",
        expects: [200, 401], query: params)
      store_authorize_params_and_login(params) if res.status == 401

      # successful authorization, clear any params in session
      self.authorize_params = nil

      authorization = MultiJson.decode(res.body)

      redirect_params = { code: authorization["code"] }
      redirect_params.merge!(state: params["state"]) if params["state"]
      base_uri = authorization["client"]["redirect_uri"]
      redirect to(build_uri(base_uri, redirect_params))
    end

    # merges extra params into a base URI
    def build_uri(base, params)
      uri        = URI.parse(base)
      uri_params = Rack::Utils.parse_query(uri.query).merge(params)
      uri.query  = Rack::Utils.build_query(uri_params)
      uri.to_s
    end

    def filter_params(*safe_params)
      safe_params.flatten!
      params.dup.keep_if { |k, v| safe_params.include?(k) }
    end

    def flash
      request.env["x-rack.flash"]
    end

    def log(action, data={})
    end

    def perform_oauth_dance(user, pass)
      api = HerokuAPI.new(user: user, pass: pass)
      res = api.post(path: "/oauth/authorize", expects: [200, 401],
        query: { client_id: Config.heroku_oauth_id, response_type: "code" })

      if res.status == 401
        flash[:error] = "There was a problem with your login."
        redirect to("/sessions/new")
      end

      code = MultiJson.decode(res.body)["code"]

      # exchange authorization code for access grant
      res = api.post(path: "/oauth/token", expects: 200,
        query: { code: code, client_secret: Config.heroku_oauth_secret })

      MultiJson.decode(res.body)
    end

    def store_authorize_params_and_login(authorize_params)
      # store to session
      self.authorize_params = authorize_params
      redirect to("/sessions/new")
    end
  end
end
