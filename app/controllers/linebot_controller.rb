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
                 せいぜい俗物らしく雨に打たれるのだな"
            else
              push =
                "明日はどうやら雨は降らなそうだ\n
                 これで決まったな\n
                 ゼダンの門にはアクシズをぶつける！"
            end

          # 明後日の天気を返す
          when /.*(明後日|あさって).*/
              per06to12 = doc.elements[xpath + 'info[3]/rainfallchance/period[2]'].text
              per12to18 = doc.elements[xpath + 'info[3]/rainfallchance/period[3]'].text
              per18to24 = doc.elements[xpath + 'info[3]/rainfallchance/period[4]'].text
              if per06to12.to_i >= min_per || per12to18.to_i >= min_per || per18to24.to_i >= min_per
                push =
                  "明後日......\n
                   なんだこのプレッシャーは......\n
                   この私にこんなにもプレッシャーをかけた......\n
                   あれは、危険すぎる......"
              else
                push =
                  "コロニーに住む人々の協力を得ることは大事なことだ\n
                   我々の仕事がやりやすくなる。\n
                   よく心に止めておけよ"
              end

        # 様々なコメント用
        when /.*(可愛い|かわいい|好き|すき|ハマーン).*/
          push = "黙れ！俗物！"
        when /.*(ハマーン様万歳|ハマーン様).*/
          push = "こういうバカな男もいる......\n
                  世の中捨てたものではないぞ"
        when /.*(死|ジュドー|カミーユ|アムロ|キュベレイ|ニュータイプ).*/
          push = "強い子に会えて......。"

        # それ以外のコメントで天気を返す
        else
           per06to12 = doc.elements[xpath + 'info/rainfallchance/period[2]l'].text
           per12to18 = doc.elements[xpath + 'info/rainfallchance/period[3]l'].text
           per18to24 = doc.elements[xpath + 'info/rainfallchance/period[4]l'].text
           if per06to12.to_i >= min_per || per12to18.to_i >= min_per || per18to24.to_i >= min_per
             word =
                ["私は宇宙の力を手にした\n
                  引力に魂を引かれたティターンズなど\n
                  恐るに足らん",
                 "型通りにはまらぬ事も時としてある\n
                  綺麗ごとだけでは済まないという事も\n
                  心に止めておくのだぞ",
                 "人は生きる限り一人だよ\n
                  人類そのものもそうだ"].sample
              push = "#{word}"
            else
              word =
                ["このごに及んで私な感情で動くとは\n
                  はじめは私に期待を抱かせて\n
                  最後の最後に私を裏切る",
                 "時代は確実に動いている\n
                  倒すべき敵、それは\n
                  カミーユ・ビダン、そういうことか",
                 "この力を誰も阻止できぬことを\n
                  思い知らせなければ意味がない\n
                  少しの希望でも残せば\n
                  また人は立ち上がろうとするのだから"].sample
              push = "#{word}"
           end
        end

      # テキスト以外（画像等）のメッセージが送られた場合
      else
        push = "よくもずけずけと人の心の中に入る。恥を知れ、俗物"
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
    @client ||= Line::Bot::Client.new { |config|
      config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
      config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
    }
  end
end
