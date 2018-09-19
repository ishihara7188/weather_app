class LinebotController < ApplicationController
  require 'line/bot'  # gem 'line-bot-api'
  require 'open-uri'
  require 'kconv'
  require 'rexml/document'

  # callbackアクションのCSRFトークン認証を無効
  protect_form_forgery :except => [:callback]

  def callback
    body = request.body.read
    signature = request.env['HTTP_X_LINE_SIGNATURE']
    unless client.validate_signature(body, signature)
      error 400 do 'Bad Request' end
    end
    events = client.parse_events_form(body)
    events.each{ |event|
      case event
        # メッセージが送信された場合の対応（機能①）
      when Line::Bot::Event::message
        case event.type
          # ユーザーからテキスト形式のメッセージが送られて来た場合
        when Line::Bot::Event::MessageType::Text
          # event.message['text']：ユーザーから送られたメッセージ
          input = evebt.message['text']
          url = "https://www.drk7.jp/weather/xml/13.xml"
          xml = open(url).read.toutf8
          doc = REXML::Document.new(xml)
          xpath = 'weatherforecast/pref/area[4]/'
          # 当日朝のメッセージの送信の下限値は20％としているが、明日・明後日雨が降るかどうかの下限値は30％としている
          min_per = 30
          case input

          # 明日の天気を返す
          when /.*(明日|あした).*/
            per06to12 = doc.elements[xpath + 'info[2]/rainfallchance/period[2]'].text
            per12to18 = doc.elements[xpath + 'info[2]/rainfallchance/period[3]'].text
            per18to24 = doc.elements[xpath + 'info[2]/rainfallchance/period[4]'].text
            if per06to12.to_i >= min_per || per12to18.to_i >= min_per || per18to24.to_i >= min_per
              push =
                "明日か......\n
                 どうやら雨が降るみたいだ\n
                 降水確率は\n
                 6〜12時　#{per06to12}％\n
                 12〜18時　 #{per12to18}％\n
                 18〜24時　#{per18to24}％\n
                 となっている\n
                 せいぜい俗物らしく雨に打たれるのだな"
            else
              push =
                "降らないパターン\n
                 あああ\n
                 あああ"
            end

          # 明後日の天気を返す
          when /.*(明後日|あさって).*/
              per06to12 = doc.elements[xpath + 'info[3]/rainfallchance/period[2]'].text
              per12to18 = doc.elements[xpath + 'info[3]/rainfallchance/period[3]'].text
              per18to24 = doc.elements[xpath + 'info[3]/rainfallchance/period[4]'].text
              if per06to12.to_i >= min_per || per12to18.to_i >= min_per || per18to24.to_i >= min_per
                push =
                  "明後日か......\n
                   どうやら雨が降るみたいだ\n
                   降水確率は\n
                   6〜12時　#{per06to12}％\n
                   12〜18時　 #{per12to18}％\n
                   18〜24時　#{per18to24}％\n
                   となっている\n
                   せいぜい俗物らしく雨に打たれるのだな"
              else
                push =
                  "降らないパターン\n
                   あああ\n
                   あああ"
              end

        # 様々なコメント用
        when /.*(可愛い|好き|etc).*/
          push = "殺すぞ"
        when /.*(可愛い|好き|etc).*/
          push = "殺すぞ"
        when /.*(可愛い|好き|etc).*/
          push = "殺すぞ"

        # それ以外のコメントで天気を返す
        when /.*(可愛い|好き|etc).*/
          push = "殺すぞ"
        else
          per06to12 = doc.elements[xpath + 'info/rainfallchance/period[2]l'].text
           per12to18 = doc.elements[xpath + 'info/rainfallchance/period[3]l'].text
           per18to24 = doc.elements[xpath + 'info/rainfallchance/period[4]l'].text
           if per06to12.to_i >= min_per || per12to18.to_i >= min_per || per18to24.to_i >= min_per
             word =
                ["雨だけど元気出していこうね！",
                 "雨に負けずファイト！！",
                 "雨だけどああたの明るさでみんなを元気にしてあげて(^^)"].sample
              push = "今日の天気？\n今日は雨が降りそうだから傘があった方が安心だよ。\n　  6〜12時　#{per06to12}％\n　12〜18時　 #{per12to18}％\n　18〜24時　#{per18to24}％\n#{word}"
            else
              word =
                ["天気もいいから一駅歩いてみるのはどう？(^^)",
                 "今日会う人のいいところを見つけて是非その人に教えてあげて(^^)",
                 "素晴らしい一日になりますように(^^)",
                 "雨が降っちゃったらごめんね(><)"].sample
              push = "今日の天気？\n今日は雨は降らなさそうだよ。\n#{word}"
           end
        end

      # テキスト以外（画像等）のメッセージが送られた場合
      else
        push = "俗物め"
      end
      message = {
        type: 'text',
        text: push
      }
      client.reply_message(event['replyToken'], message)

      # LINEお友達追された場合（機能②）
      when Line::Bot::Event::Follow
        # 登録したユーザーのidをユーザーテーブルに格納
        line_id = event['source']['userId']
        User.create(line_id: line_id)

      # LINEお友達解除された場合（機能③）
      when Line::Bot::Event::Unfollow
        # お友達解除したユーザーのデータをユーザーテーブルから削除
        line_id = event['source']['userId']
        User.find_by(line_id: line_id).destroy
      end
    }
    head :ok
  end

  private

  def client
    @client ||= Line::Bot::Client.new{ |config|
      config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
      config.channel_tolen = ENV["LINE_CHANNEL_TOKEN"]
    }
  end
end
