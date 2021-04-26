class UpsertPartnerForProSanteConnectService < BaseService
  attr_reader :partner, :omniauth_info

  def initialize(omniauth_info)
    @omniauth_info = omniauth_info
  end

  def perform
    Rails.logger.debug(omniauth_info.to_json)
    @partner = Partner.find_by(pro_sante_connect_openid_sub: omniauth_info.sub) \
      || Partner.find_by(email: omniauth_info.email)
    puts @partner
    @new_partner = @partner.nil?
    if @partner.nil?
      # create_new_partner
    elsif !@partner.logged_once_with_pro_sante_connect?
      # update_existing_partner
    end
    self
  end

  private

  def update_existing_partner
    @partner.update!(partner_attribute_values_from_pro_sante_connect)
  end

  def create_new_partner
    @partner = Partner.new(
      partner_attribute_values_from_pro_sante_connect.merge(
        email: omniauth_info.email,
        created_through: "pro_sante_connect_sign_up"
      )
    )
    @partner.skip_confirmation!
    # @partner.save!
    @partner
  end

  def xxxx
    {
      first_name: omniauth_info.given_name,
      birth_name: omniauth_info.family_name, # nom de naissance
      birth_date: omniauth_info.birthdate,
      pro_sante_connect_openid_sub: omniauth_info.sub,
      last_name: omniauth_info.preferred_partnername.presence || omniauth_info.family_name, # nom d'usage (optionnel),
      logged_once_with_pro_sante_connect: true
    }.compact # do not fill with missing values
  end
end
