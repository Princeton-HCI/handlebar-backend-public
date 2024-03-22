defmodule DriversSeatCoop.Marketing.Campaigns.WelcomeToWaoDriversSeat do
  alias DriversSeatCoop.Marketing.Campaign
  alias DriversSeatCoop.Marketing.CampaignAction
  alias DriversSeatCoop.Marketing.Survey
  alias DriversSeatCoop.Marketing.SurveySection

  @campaign_id :welcome_to_wao_drivers_seat

  def get_id, do: @campaign_id

  def instance do
    Survey.new(@campaign_id)
    |> Campaign.with_category(:interrupt)
    |> Survey.with_section([
      SurveySection.new(:page_1)
      |> SurveySection.with_content_url("#{@campaign_id}/page1.html"),
      SurveySection.new(:page_2)
      |> SurveySection.with_content_url("#{@campaign_id}/page2.html"),
      SurveySection.new(:page_3)
      |> SurveySection.with_content_url("#{@campaign_id}/page3.html")
      |> SurveySection.with_action([
        CampaignAction.new(:read_blog, :custom, "Check out the blog post")
        |> CampaignAction.with_url("https://www.driversseat.co")
      ]),
      SurveySection.new(:page_4)
      |> SurveySection.with_content_url("#{@campaign_id}/page4.html")
      |> SurveySection.with_action([
        CampaignAction.new(:send_email, :custom, [
          "Send us an email"
        ])
        |> CampaignAction.with_url("mailto:thewao@princeton.edu"),
        CampaignAction.new(:join_whatsapp, :custom, "Join our WhatsApp Community")
        |> CampaignAction.with_url("https://chat.whatsapp.com/LmRmBhGmko6AcHrG1pMjyT")
      ]),
      SurveySection.new(:page_5)
      |> SurveySection.with_content_url("#{@campaign_id}/page5.html")
      |> SurveySection.with_action([
        CampaignAction.new(:finish, :accept, "Let's Get Started!")
      ])
    ])
  end
end
