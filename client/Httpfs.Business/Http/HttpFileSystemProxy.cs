using System;
using System.IO;
using System.Linq;
using System.Net;
using System.Text;
using System.Threading.Tasks;

using httpfsc.Business.Http.FileSystem.Exceptions;
using httpfsc.Business.Http.FileSystem.Results;

using RestSharp;

namespace httpfsc.Business.Http
{
    public class HttpFileSystemProxy
    {
        #region Constructors

        public HttpFileSystemProxy(IHttpFileSystemProxyConfig config)
        {
            this.Client = new RestClient { BaseUrl = new Uri(config.ServerRootPath) };
        }

        #endregion

        #region Properties

        private RestClient Client { get; set; }

        #endregion

        #region Methods

        public async Task<ListDirectoryResult> ListDirectory(Url path, Action<HttpStatusCode, string> errorHandler)
        {
            var request = new RestRequest(path, Method.GET);

            var files = await this.Client.ExecuteGetTaskAsync(request);

            if (files.Headers.All(h => h.Name != "is-directory"))
            {
                throw new NotADirectoryException();
            }

            if (files.StatusCode == HttpStatusCode.OK)
            {
                return files.Content != null
                    ? ListDirectoryResult.FromResponse(files.Content)
                    : ListDirectoryResult.FromEmptyResponse();
            }

            if (errorHandler != null)
            {
                errorHandler(files.StatusCode, files.StatusDescription);
            }

            return null;
        }
        
        public async Task DownloadFile(Url path, Url to, Action<HttpStatusCode, string> errorHandler)
        {
            var request = new RestRequest(path, Method.GET);

            var fileBytes = await this.Client.ExecuteGetTaskAsync(request);

            if (fileBytes.Headers.Any(h => h.Name == "is-directory"))
            {
                throw new NotADirectoryException();
            }

            if (fileBytes.StatusCode == HttpStatusCode.OK)
            {
                if (!Directory.Exists(to.GetDirectoryName()))
                {
                    Directory.CreateDirectory(to.GetDirectoryName());
                }

                File.WriteAllText(to.GetFullPath(), fileBytes.Content, Encoding.Default);
            }
            else if (errorHandler != null)
            {
                errorHandler(fileBytes.StatusCode, fileBytes.StatusDescription);
            }
        }

        public async Task UploadFile(Url to, string file, Action<HttpStatusCode, string> errorHandler)
        {
            await this.CreateEmptyFile(to, (code, s) => { });

            var request = new RestRequest(to, Method.PUT);
            request.AddParameter("file", file, ParameterType.RequestBody);

            var response = await this.Client.ExecuteTaskAsync(request);

            if (errorHandler != null)
            {
                errorHandler(response.StatusCode, response.StatusDescription);
            }
        }

        public async Task CreateEmptyFile(Url path, Action<HttpStatusCode, string> errorAction)
        {
            var request = new RestRequest(path, Method.POST);
            var response = await this.Client.ExecutePostTaskAsync(request);

            if (errorAction != null)
            {
                errorAction.Invoke(response.StatusCode, response.StatusDescription);
            }
        }

        public async Task DeleteFile(Url path, Action<HttpStatusCode, string> errorAction)
        {
            var request = new RestRequest(path, Method.DELETE);
            var response = await this.Client.ExecuteTaskAsync(request);

            if (errorAction != null)
            {
                errorAction.Invoke(response.StatusCode, response.StatusDescription);
            }
        }

        public async Task DeleteFolder(Url path, Action<HttpStatusCode, string> errorAction)
        {
            var request = new RestRequest(path, Method.DELETE);
            request.AddHeader("is-directory", "pls");

            var response = await this.Client.ExecuteTaskAsync(request);

            if (errorAction != null)
            {
                errorAction.Invoke(response.StatusCode, response.StatusDescription);
            }
        }

        public async Task CreateFolder(Url path, Action<HttpStatusCode, string> errorAction)
        {
            var request = new RestRequest(path, Method.POST);
            request.AddHeader("is-directory", "pls");

            var response = await this.Client.ExecutePostTaskAsync(request);

            if (errorAction != null)
            {
                errorAction.Invoke(response.StatusCode, response.StatusDescription);
            }
        }

        #endregion
    }
}