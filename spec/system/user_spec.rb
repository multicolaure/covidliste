require "rails_helper"

def robust_password
  "1G09_!9s08vUsa"
end

def fill_valid_user
  fill_in :user_address, with: generate(:french_address)
  fill_in :user_phone_number, with: generate(:french_phone_number)
  fill_in :user_email, with: "hello+#{(rand * 10000).to_i}@covidliste.com" # needs valid email here
  check :user_statement
  check :user_toc
end

def signup_submit
  click_on "S’inscrire"
end

RSpec.describe "Users", type: :system do
  let(:user) { build(:user) }

  before do
    allow_any_instance_of(GeocodingService).to receive(:call).and_return({
      lat: 48.12345,
      lon: 2.12345
    })
  end

  context "sign up" do
    it "can sign up" do
      expect do
        visit "/"
        fill_valid_user
        signup_submit
      end.to change { User.count }.by(1)
    end

    it "rejects sign up if address has no zipcode valid" do
      user.save!

      expect do
        visit "/"
        fill_valid_user
        fill_in :user_address, with: "5 rue Larue, Marseille" # no zipcode
        signup_submit
      end.not_to change { User.count }

      expect(page).to have_text("doit comporter un code postal")
    end

    it "rejects sign up if email is not unique" do
      user.save!

      expect do
        visit "/"
        fill_valid_user
        fill_in :user_email, with: user.email # not unique
        signup_submit
      end.not_to change { User.count }

      expect(page).to have_text("correspond déjà à une personne inscrit")
    end

    it "rejects sign up if statement is not checked" do
      expect do
        visit "/"
        fill_valid_user
        uncheck :user_statement
        signup_submit
      end.not_to change { User.count }
    end

    it "rejects sign up if toc is not checked" do
      expect do
        visit "/"
        fill_valid_user
        uncheck :user_toc
        signup_submit
      end.not_to change { User.count }
    end

    it "stores statement and toc acceptance timestamps" do
      expect do
        visit "/"
        fill_valid_user
        signup_submit
      end.to change { User.count }.by(1)

      user = User.last
      expect(user.statement_accepted_at).not_to be_nil
      expect(user.toc_accepted_at).not_to be_nil
    end

    it "redirects a partner to their vaccination center page" do
      partner = create(:partner)
      visit new_partner_session_path

      fill_in :partner_email, with: partner.email
      fill_in :partner_password, with: partner.password
      click_on "Connexion"

      visit "/"

      expect(page).to have_text("Bonjour #{partner.name}")
    end
  end

  context "after login" do
    before do
      user.save!

      token = Devise::Passwordless::LoginToken.encode(user)
      visit users_magic_link_url(Hash["user", {email: user.email, token: token}])

      expect(page).to have_text("Connecté(e).")
      expect(page).to have_text("Accélérons la campagne de vaccination.")

      visit profile_url
    end

    it "it allows me to edit personal information " do
      new_attributes = {
        phone_number: generate(:french_phone_number)
      }

      new_attributes.each do |key, new_value|
        fill_in "user_#{key}", with: new_value
      end

      click_on "Je modifie mes informations"
      expect(page).to have_text("Modifications enregistrées.")

      user.reload

      new_attributes.each do |key, value|
        if key == :phone_number
          expect(user.phone_number).to end_with(new_attributes[:phone_number][1..].delete(" "))
        else
          expect(user.public_send(key)).to eq value
        end
      end
    end

    it "it allows me to delete my account" do
      expect do
        accept_confirm_modal do
          click_on "Supprimer mon compte"
        end
      end.to change { User.count }.by(-1)

      expect(page).to have_text("Votre compte a bien été supprimé.")
    end

    it "it allows me to decline the delete" do
      expect do
        decline_confirm_modal do
          click_on "Supprimer mon compte"
        end
      end.to change { User.count }.by(0)
    end

    context "with a confirmed match" do
      let(:campaign) { build(:campaign) }
      let!(:match) { create(:match, campaign: campaign, confirmed_at: Time.now, user: user) }

      it "it doest not allow me to edit personal information " do
        click_on "Je modifie mes informations"
        expect(page).not_to have_text("Modifications enregistrées.")
        expect(page).to have_text("Vous ne pouvez pas modifier vos informations actuellement car vous avez confirmé un rendez-vous de vaccination.")
      end
    end

    context "with a pending match" do
      let(:campaign) { build(:campaign) }
      let!(:match) { create(:match, campaign: campaign, confirmed_at: nil, expires_at: 10.minutes.since, user: user) }

      it "it doest not allow me to edit personal information " do
        click_on "Je modifie mes informations"
        expect(page).not_to have_text("Modifications enregistrées.")
        expect(page).to have_text("Vous ne pouvez pas modifier vos informations actuellement car vous avez une proposition rendez vous de vaccination en cours.")
      end
    end
  end

  describe "Login using password less link" do
    before { user.save! }
    context "expired link" do
      scenario "it notifies the user" do
        token = Devise::Passwordless::LoginToken.encode(user)
        magic_link = users_magic_link_url(Hash["user", {email: user.email, token: token}])

        travel Devise.passwordless_login_within + 2.minutes
        visit magic_link

        expect(page).to_not have_current_path(profile_path)
        expect(page).to have_text(I18n.t("devise.failure.user.magic_link_invalid"))
      end
    end

    context "invalid link (remove last character)" do
      scenario "it notifies the user" do
        token = Devise::Passwordless::LoginToken.encode(user)[0...-1]
        magic_link = users_magic_link_url(Hash["user", {email: user.email, token: token}])

        visit magic_link

        expect(page).to_not have_current_path(profile_path)
        expect(page).to have_text(I18n.t("devise.failure.user.magic_link_invalid"))
      end
    end
  end
end
