import os

import requests
import streamlit as st

BACKEND_URL = os.getenv("BACKEND_URL", "http://localhost:8000")

st.set_page_config(page_title="Sample Dev App", page_icon="📝", layout="centered")
st.title("Sample Memo App")
st.caption(f"backend: {BACKEND_URL}")

# --- 新規メモ作成 ---
with st.form("new_memo_form", clear_on_submit=True):
    st.subheader("新しいメモを作成")
    title = st.text_input("タイトル")
    content = st.text_area("内容")
    submitted = st.form_submit_button("追加")

    if submitted:
        if not title:
            st.error("タイトルは必須です")
        else:
            try:
                res = requests.post(
                    f"{BACKEND_URL}/memos",
                    json={"title": title, "content": content},
                    timeout=5,
                )
                res.raise_for_status()
                st.success("メモを追加しました")
            except requests.RequestException as e:
                st.error(f"バックエンドへの接続に失敗しました: {e}")

st.divider()

# --- 一覧表示 ---
st.subheader("メモ一覧")

if st.button("🔄 再読み込み"):
    st.rerun()

try:
    res = requests.get(f"{BACKEND_URL}/memos", timeout=5)
    res.raise_for_status()
    memos = res.json()
except requests.RequestException as e:
    st.error(f"バックエンドへの接続に失敗しました: {e}")
    memos = []

if not memos:
    st.info("メモがまだありません")

for memo in memos:
    with st.container(border=True):
        col1, col2 = st.columns([5, 1])
        with col1:
            st.markdown(f"**{memo['title']}**")
            if memo.get("content"):
                st.write(memo["content"])
            st.caption(memo.get("created_at", ""))
        with col2:
            if st.button("削除", key=f"del_{memo['id']}"):
                try:
                    d = requests.delete(f"{BACKEND_URL}/memos/{memo['id']}", timeout=5)
                    d.raise_for_status()
                    st.rerun()
                except requests.RequestException as e:
                    st.error(f"削除に失敗しました: {e}")