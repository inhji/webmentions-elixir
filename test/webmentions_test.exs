defmodule WebmentionsTest do
  use ExUnit.Case, async: false
  doctest Webmentions

  import Mock

  test "discovers from a link in header" do
    doc = %HTTPoison.Response{
      status_code: 200,
      body: "<html>",
      headers: [{"Link", "<http://example.org/webmentions>; rel=\"webmention\""}]
    }

    with_mock HTTPoison, get: fn _url, _headers, _opts -> {:ok, doc} end do
      assert Webmentions.discover_endpoint("http://example.org") == {:ok, "http://example.org/webmentions"}
    end
  end

  test "discovers from a link in header case-insensitive" do
    doc = %HTTPoison.Response{
      status_code: 200,
      body: "<html>",
      headers: [{"link", "<http://example.org/webmentions>; rel=\"webmention\""}]
    }

    with_mock HTTPoison, get: fn _url, _headers, _opts -> {:ok, doc} end do
      assert Webmentions.discover_endpoint("http://example.org") == {:ok, "http://example.org/webmentions"}
    end
  end

  test "discovers from a link in document" do
    doc = %HTTPoison.Response{
      status_code: 200,
      body: "<html><head><link rel=\"webmention\" href=\"http://example.org/webmentions\">",
      headers: [{"Content-Type", "text/html"}]
    }

    with_mock HTTPoison, get: fn _url, _headers, _opts -> {:ok, doc} end do
      assert Webmentions.discover_endpoint("http://example.org") == {:ok, "http://example.org/webmentions"}
    end
  end

  test "discovers from multiple links in document" do
    doc = %HTTPoison.Response{
      status_code: 200,
      body: """
      <html>
      <head>
      <link rel="webmention" href="http://example.org/webmentions">
      <link rel="micropub" href="http://example.org/micropub">
      <link rel="token_endpoint" href="http://example.org/login">
      <link rel="authorization_endpoint" href="https://indieauth.com/auth">
      <link rel="hub" href="https://switchboard.p3k.io">
      <link rel="self" href="http://example.org">
      """,
      headers: [{"Content-Type", "text/html"}]
    }

    with_mock HTTPoison, get: fn _url, _headers, _opts -> {:ok, doc} end do
      assert Webmentions.discover_endpoint("http://example.org") == {:ok, "http://example.org/webmentions"}
    end
  end

  test "discovers from a link list in header" do
    doc = %HTTPoison.Response{
      status_code: 200,
      body: "<html>",
      headers: [
        {"Link",
         "<http://example.org/webmentions>; rel=\"webmention\", <http://example.org/micropub>; rel=\"micropub\", <http://example.org/login>; rel=\"token_endpoint\", <https://indieauth.com/auth>; rel=\"authorization_endpoint\", <https://switchboard.p3k.io>; rel=\"hub\", <http://example.org>; rel=\"self\""}
      ]
    }

    with_mock HTTPoison, get: fn _url, _headers, _opts -> {:ok, doc} end do
      assert Webmentions.discover_endpoint("http://example.org") == {:ok, "http://example.org/webmentions"}
    end
  end

  test "discovers from a link list in header when not first element" do
    doc = %HTTPoison.Response{
      status_code: 200,
      body: "<html>",
      headers: [
        {"Link",
         "<http://example.org/micropub>; rel=\"micropub\", <http://example.org/login>; rel=\"token_endpoint\", <http://example.org/webmentions>; rel=\"webmention\", <https://indieauth.com/auth>; rel=\"authorization_endpoint\", <https://switchboard.p3k.io>; rel=\"hub\", <http://example.org>; rel=\"self\""}
      ]
    }

    with_mock HTTPoison, get: fn _url, _headers, _opts -> {:ok, doc} end do
      assert Webmentions.discover_endpoint("http://example.org") == {:ok, "http://example.org/webmentions"}
    end
  end

  test "ignores an empty link in header" do
    doc = %HTTPoison.Response{status_code: 200, body: "<html>", headers: [{"Link", ""}]}

    with_mock HTTPoison, get: fn _url, _headers, _opts -> {:ok, doc} end do
      assert Webmentions.discover_endpoint("http://example.org") == {:ok, nil}
    end
  end

  test "resolves an empty link in document to document URL" do
    doc = %HTTPoison.Response{
      status_code: 200,
      body: "<html><head><link rel=\"webmention\" href=\"\">",
      headers: [{"Content-Type", "text/html"}]
    }

    with_mock HTTPoison, get: fn _url, _headers, _opts -> {:ok, doc} end do
      assert Webmentions.discover_endpoint("http://example.org") == {:ok, "http://example.org"}
    end
  end

  test "correctly sends a mention to example.org/webmentions" do
    doc = %HTTPoison.Response{
      status_code: 200,
      body: "<html class=\"h-entry\"><a href=\"http://example.org/test\">blah</a>",
      headers: [{"Link", "<http://example.org/webmentions>; rel=\"webmention\""}]
    }

    with_mock HTTPoison,
      get: fn _url, _headers, _opts -> {:ok, doc} end,
      post: fn _url, _headers, _opts -> {:ok, doc} end do
      assert Webmentions.send_webmentions("http://example.org") ==
               {:ok, [{:ok, "http://example.org/test", "http://example.org/webmentions", "sent"}]}
    end
  end

  test "doesn't send a webmention to a rel=nofollow" do
    doc = %HTTPoison.Response{
      status_code: 200,
      body: "<html class=\"h-entry\"><a rel=\"nofollow\" href=\"http://example.org/test\">blah</a>",
      headers: [{"Link", "<http://example.org/webmentions>; rel=\"webmention\""}]
    }

    with_mock HTTPoison,
      get: fn _url, _headers, _opts -> {:ok, doc} end,
      post: fn _url, _headers, _opts -> {:ok, doc} end do
      assert Webmentions.send_webmentions("http://example.org") == {:ok, []}
    end
  end

  test "successfully sends mentions to relative URLs" do
    doc = %HTTPoison.Response{
      status_code: 200,
      body: "<html class=\"h-entry\"><a href=\"/test\">blah</a>",
      headers: [{"Link", "<http://example.org/webmentions>; rel=\"webmention\""}]
    }

    with_mock HTTPoison,
      get: fn url, _headers, _opts ->
        assert url != "/test"
        {:ok, doc}
      end,
      post: fn _url, _headers, _opts -> {:ok, doc} end do
      assert Webmentions.send_webmentions("http://example.org") ==
               {:ok, [{:ok, "http://example.org/test", "http://example.org/webmentions", "sent"}]}
    end
  end

  test "successfully mentions a HTTP ressource" do
    assert Webmentions.send_webmentions_for_doc(
             "<html class=\"h-entry\"><a href=\"http://images1.dawandastatic.com/Product/18223/18223505/big/1301969630-83.jpg\">blah</a>",
             "http://example.org/"
           ) ==
             {:ok,
              [
                {:ok, "http://images1.dawandastatic.com/Product/18223/18223505/big/1301969630-83.jpg", nil,
                 "no endpoint found"}
              ]}
  end

  test "doesn't send a mention with empty link" do
    doc = %HTTPoison.Response{
      status_code: 200,
      body: "<html class=\"h-entry\"><a href=\"http://example.org/test\">blah</a>",
      headers: [{"Link", ""}]
    }

    with_mock HTTPoison,
      get: fn _url, _headers, _opts -> {:ok, doc} end,
      post: fn _url, _headers, _opts -> {:ok, doc} end do
      assert Webmentions.send_webmentions("http://example.org") ==
               {:ok, [{:ok, "http://example.org/test", nil, "no endpoint found"}]}
    end
  end
end
