from app.cli import build_parser


def test_parser_create_token():
    args = build_parser().parse_args(["create-token", "iPhone"])
    assert args.command == "create-token"
    assert args.name == "iPhone"


def test_parser_list_and_revoke():
    assert build_parser().parse_args(["list-tokens"]).command == "list-tokens"
    args = build_parser().parse_args(["revoke-token", "1234"])
    assert args.command == "revoke-token"
    assert args.token_id == "1234"
