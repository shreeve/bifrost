require "./spec_helper"

describe RealtimeService do
  # You can use get,post,put,patch,delete to call the corresponding route.
  it "renders /" do
    get "/"
    response.body.should contain "connecting"
  end

  describe "POST /broadcast" do
    context "invalid JWT" do
      it "returns bad request" do
        payload = {
          exp: Time.now.epoch + 3600, # 1 hour
        }
        jwt = JWT.encode(payload, "bad-secret-key", "HS512")
        post "/broadcast", headers: HTTP::Headers{"Content-Type" => "application/json"}, body: {token: jwt}.to_json

        response.status_code.should eq 400
      end
    end

    context "expired JWT" do
      it "returns bad request" do
        payload = {
          exp: Time.now.epoch - 10,
        }
        jwt = JWT.encode(payload, ENV["JWT_SECRET"], "HS512")
        post "/broadcast", headers: HTTP::Headers{"Content-Type" => "application/json"}, body: {token: jwt}.to_json

        puts response.body
        response.status_code.should eq 400
      end
    end

    context "valid JWT" do
    end
  end
end