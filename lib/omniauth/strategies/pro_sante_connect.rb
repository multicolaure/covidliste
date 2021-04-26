require "omniauth_openid_connect"

module OmniAuth
  module Strategies
    class ProSanteConnect < OpenIDConnect
      # info do
      #  {
      #    sub: user_info.sub,
      #    given_name: user_info.given_name,
      #    family_name: user_info.family_name,
      #    email: user_info.email
      #  }
      # end
    end
  end
end

OmniAuth.config.add_camelization("pro_sante_connect", "ProSanteConnect")
