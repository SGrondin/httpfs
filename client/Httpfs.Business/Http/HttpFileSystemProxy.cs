using System;
using System.IO;
using System.Linq;
using System.Net;
using System.Text;
using System.Threading.Tasks;

using Httpfsc.Business.Http.FileSystem.Exceptions;
using Httpfsc.Business.Http.FileSystem.Results;

using RestSharp;

namespace Httpfsc.Business.Http
{
    /// <summary>
    /// Proxy au système de fichiers distribués.
    /// </summary>
    public class HttpFileSystemProxy : IHttpFileSystemProxy
    {
        #region Constructors

        public HttpFileSystemProxy(IHttpFileSystemProxyConfig config)
        {
            this.Client = new RestClient { BaseUrl = new Uri(config.ServerRootPath) };
        }

        #endregion

        #region Properties

        /// <summary>
        /// Le HTTP Client.
        /// </summary>
        /// <value>Le HTTP client.</value>
        private RestClient Client { get; set; }

        #endregion

        #region Methods

        /// <summary>
        /// Get the contents of a directory.
        /// </summary>
        /// <param name="path">Remote relative path.</param>
        /// <param name="errorHandler">The error handler.</param>
        /// <returns>The <see cref="Task"/>.</returns>
        /// <exception cref="NotADirectoryException"></exception>
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

        /// <summary>
        /// Download a file.
        /// </summary>
        /// <param name="path">Remote relative path of file to download.</param>
        /// <param name="to">Local absolute path to write the file.</param>
        /// <param name="errorHandler">The error handler.</param>
        /// <returns>The <see cref="Task"/>.</returns>
        /// <exception cref="NotADirectoryException">Si path indique un répertoire.</exception>
        public async Task DownloadFile(Url path, Url to, Action<HttpStatusCode, string> errorHandler)
        {
            if (to == null) throw new ArgumentNullException("to");
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

                File.WriteAllText(to.FullPath, fileBytes.Content, Encoding.Default);
            }
            else if (errorHandler != null)
            {
                errorHandler(fileBytes.StatusCode, fileBytes.StatusDescription);
            }
        }

        /// <summary>
        /// Upload a file.
        /// </summary>
        /// <param name="to">Remote relative path to write the file.</param>
        /// <param name="file">Local absolute path of file to upload.</param>
        /// <param name="errorHandler">The error handler.</param>
        /// <returns>The <see cref="Task"/>.</returns>
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

        /// <summary>
        /// Create empty file.
        /// </summary>
        /// <param name="path">Remote relative path to write the file.</param>
        /// <param name="errorHandler">The error handler.</param>
        /// <returns>The <see cref="Task"/>.</returns>
        public async Task CreateEmptyFile(Url path, Action<HttpStatusCode, string> errorHandler)
        {
            var request = new RestRequest(path, Method.POST);
            var response = await this.Client.ExecutePostTaskAsync(request);

            if (errorHandler != null)
            {
                errorHandler.Invoke(response.StatusCode, response.StatusDescription);
            }
        }

        /// <summary>
        /// Delete a file.
        /// </summary>
        /// <param name="path">Remote relative path of the file to be deleted.</param>
        /// <param name="errorHandler">The error handler.</param>
        /// <returns>The <see cref="Task"/>.</returns>
        public async Task DeleteFile(Url path, Action<HttpStatusCode, string> errorHandler)
        {
            var request = new RestRequest(path, Method.DELETE);
            var response = await this.Client.ExecuteTaskAsync(request);

            if (errorHandler != null)
            {
                errorHandler.Invoke(response.StatusCode, response.StatusDescription);
            }
        }

        /// <summary>
        /// Delete a directory.
        /// </summary>
        /// <param name="path">Remote relative path of the directory to be deleted.</param>
        /// <param name="errorHandler">The error handler.</param>
        /// <returns>The <see cref="Task"/>.</returns>
        public async Task DeleteDirectory(Url path, Action<HttpStatusCode, string> errorHandler)
        {
            var request = new RestRequest(path, Method.DELETE);
            request.AddHeader("is-directory", "pls");

            var response = await this.Client.ExecuteTaskAsync(request);

            if (errorHandler != null)
            {
                errorHandler.Invoke(response.StatusCode, response.StatusDescription);
            }
        }

        /// <summary>
        /// Create a directory.
        /// </summary>
        /// <param name="path">Le chemin relatif distant du fichier à créer.</param>
        /// <param name="errorHandler">The error handler.</param>
        /// <returns>The <see cref="Task"/>.</returns>
        public async Task CreateDirectory(Url path, Action<HttpStatusCode, string> errorHandler)
        {
            var request = new RestRequest(path, Method.POST);
            request.AddHeader("is-directory", "pls");

            var response = await this.Client.ExecutePostTaskAsync(request);

            if (errorHandler != null)
            {
                errorHandler.Invoke(response.StatusCode, response.StatusDescription);
            }
        }

        #endregion
    }
}