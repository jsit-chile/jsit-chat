import axios from 'axios';

const { apiHost = '' } = window.jChatConfig || {};
const wootAPI = axios.create({ baseURL: `${apiHost}/` });

export default wootAPI;
